# Capture widget

Replace the bar's record-only widget with a capture widget covering screenshots
and recordings, and add a post-capture preview card offering copy, edit, and
discard.

Date: 2026-08-28

## Problem

Three things are wrong today.

**Screenshots have no presence in the shell.** They exist only as Hyprland
keybinds, and every one of them opens `satty` before anything is saved — the
annotation editor interrupts the capture whether or not you intended to
annotate. There is no way to take a shot and simply have it.

**The record widget offers the same two scopes twice.** Its menu is Region,
`+ Audio`, Full, `+ Audio` — audio is duplicated per scope rather than being
remembered state.

**Screenshot logic is duplicated and the shell guesses at it.**
`stow/scripts/.local/bin/system-screenshot` and
`stow/hypr/.config/hypr/actions/screenshots.lua` both implement
grim/slurp/satty independently; the keybinds use the lua copy, leaving the
script unreferenced. Meanwhile `notifications/NotificationCard.qml` sniffs
notification app names for `satty`/`flameshot`/`spectacle` and bodies for
`clipboard` to guess that a screenshot happened, so it can show a preview.

## Decision: scripts own capture, the shell owns UI

The scripts keep grim, slurp, wf-recorder, wl-screenrec, and the pipewire
audio mixing. Quickshell adds no capture logic. The shell learns about
captures through IPC.

Rejected: moving capture into QML `Process` calls. Three reasons.

1. **Debuggability.** What breaks in capture is never the UI — it is the audio
   path (`module-null-sink`, `pw-link`, the WirePlumber race documented in
   `system-screenrecord`) and encoder fallback (nvenc → vaapi → software). In
   bash that is a terminal, stderr, and `set -x`. In QML it is chained async
   subprocesses whose errors land in `quickshell log`, which serves stale lines
   from the middle of a multi-megabyte file.
2. **Blast radius.** Capture is a tool reached for when something is already
   wrong, which is when the shell is most likely to be the broken thing. With
   scripts owning capture, a dead or stale-watcher quickshell costs the preview
   card and nothing else — `Super+R` still writes the file, because Hyprland
   runs the script directly.
3. **Fit.** The audio pipeline is inherently pactl/pw-link work. Sequential
   bash expresses it; orchestrated QML subprocesses would not.

Also rejected: merging both scripts into one `system-capture`. A rewrite of
working, fiddly code for no user-visible gain.

## Architecture

```
Hyprland keybind ─┐
                  ├─→ system-screenshot ──→ grim ─→ file ─→ wl-copy
Capture popover ──┘                            │
                                               └─→ quickshell ipc call
                                                     capture saved <path>
                                                          │
Hyprland keybind ─┐                                       ▼
                  ├─→ system-screenrecord ─→ wf-recorder   CaptureState
Capture popover ──┘        │                    │            │
                           │                    └─→ file ────┤
                           ├─→ /tmp/screenrecord.state       │
                           │   (recording latch, survives    ▼
                           │    a shell restart)      CapturePreviewCard
                           └─→ quickshell ipc call
                                 capture started
```

`/tmp/screenrecord.state` is retained. IPC is a push channel with no replay: if
quickshell restarts mid-recording it has no way to learn that a recording is
running. The state file is the only restart-survivable answer to "am I
recording?", and `services/Privacy.qml` already watches it. IPC carries events
(started, saved), not state.

## Components

### New

| File | Purpose |
| --- | --- |
| `services/CaptureState.qml` | Singleton. Latest capture path/kind, preview visibility, audio-enabled toggle state, and `present(path)`. |
| `bar/widgets/CapturePopover.qml` | The popover panel: segmented body plus the LATEST band. |
| `capture/CapturePreviewWindow.qml` | Bottom-right `PanelWindow` hosting the card. |
| `capture/CapturePreviewCard.qml` | Thumbnail, filename, actions. |
| `capture/qmldir` | Module registration. |
| `config/StyleCapture.qml` | Domain tokens (see Tokens below). |

### Modified

| File | Change |
| --- | --- |
| `bar/widgets/ScreenRecord.qml` → `Capture.qml` | Renamed. Keeps the elapsed-timer trail, red pulse, and collapse animation verbatim; its popover becomes `CapturePopover`. |
| `bar/Bar.qml` | `Widgets.ScreenRecord` → `Widgets.Capture`. |
| `shell.qml` | Adds the `capture` `IpcHandler` and `CapturePreviewWindow`. |
| `config/IconRegistry.qml` | Adds the capture glyphs listed below. |
| `notifications/NotificationWindow.qml` | Bottom margin yields to the preview card (see Corner arbitration). |
| `notifications/NotificationCard.qml` | Deletes `isClipboardCopy`, `clipboardImagePath`, `clipboardSaveProcess`, `hasClipboardImage`. |
| `stow/hypr/.config/hypr/actions/screenshots.lua` | Calls `system-screenshot <mode>`; inline shell strings deleted. |
| `stow/hypr/.config/hypr/windowrules.lua` | Layer rule for the `capture-preview` namespace. |
| `stow/scripts/.local/bin/system-screenshot` | Clipboard + IPC by default; `--edit` for satty. |
| `stow/scripts/.local/bin/system-screenrecord` | IPC calls replace the `notify-send` block. |
| `DESIGN.md`, `OVERVIEW.md` | Document the widget and the one divergence below. |

## Popover layout

Width is `StylePopover.panelWidth` (320). Composed from `PopoverHeader`,
`PopoverSeparator`, `SegmentedControl`, `PopoverAction`, and `Toggle` — no new
primitives.

```
┌ Capture ───────────────────── [ 🗀 ] ┐   PopoverHeader + folder PillButton
│      ┌──── Shot ────┬─── Record ───┐ │   SegmentedControl
├──────────────────────────────────────┤   PopoverSeparator
│                                      │
│    [region]   [window]   [screen]    │   fixed-height body
│                                      │
├──────────────────────────────────────┤   PopoverSeparator
│  [thumb]  screenshot-09-14      Copy │   LATEST band
└──────────────────────────────────────┘
```

**The segmented body covers one subject: what to capture.** Per DESIGN.md's
segmented-views rule, a popover covering several subjects segments them rather
than stacking them into one scroll. Screenshot and Record are the two subjects.

- **Shot**: three stacked `PopoverAction` tiles — Region, Window, Screen.
- **Record**: two tiles — Region, Screen — plus an "Include audio" list row
  carrying a `Toggle`.

Audio is remembered state on `CaptureState`, not a per-scope menu entry. This
is what collapses today's four record entries to two, and it matches how Wi-Fi
and Bluetooth already put their switch in a header or section rather than
duplicating rows.

**Fixed body height** is required by the segments rule — a bar popover grows
upward, so a content-fit body moves the segments themselves on every switch and
the next click lands on a different tab than the one aimed at.

```
StyleCapture.bodyHeight = StylePopover.tileHeight      (58)
                        + StylePopover.listRowHeight   (44)
                        + StyleTokens.space8            (8)   = 110
```

**The LATEST band sits outside the segments.** "What I just captured" is not a
third subject competing with the other two; it is a footer that stays put while
you switch. Per the One Surface Rule it is a plain row on the same surface with
no nested elevation, card, or shadow. It shows the single most recent capture,
not a history list — actions live on the preview card. Empty state: a
`PopoverMessage` reading "No captures yet".

### Accepted divergence

On the Shot segment the fixed body is one list row taller than its content. The
tiles are centered vertically in it rather than top-aligned. DESIGN.md says to
absorb segment slack with an empty state; that guidance assumes a list, and
this body is a tile row. Centering reads as air; top-aligning reads as a hole.
Record this under **Known divergences** in DESIGN.md so it is not copied as
precedent for list bodies.

### Icons

All verified present in `assets/material-symbols.txt`.

| Use | Glyph |
| --- | --- |
| Bar button, idle | `screenshot_frame` |
| Bar button, recording | `videocam` (existing red `StyleRecording` pulse) |
| Shot / Region | `screenshot_region` |
| Shot / Window | `select_window` |
| Shot / Screen | `fullscreen` |
| Record / Region | `screen_record` |
| Record / Screen | `videocam` |
| Audio on / off | `mic` / `mic_off` |
| Open folder | `folder_open` |
| Card: copy | `content_copy` |
| Card: edit | `edit` |
| Card: play | `play_arrow` |
| Card: discard | `delete` |

The bar glyph changes with state because the affordance genuinely changes: idle
the button opens the popover, recording it stops the recording.

## Preview card

Bottom-right, reusing `NotificationWindow`'s anchoring and
`NotificationCard`'s hover-pauses-expiry timer.

```
┌────────────────────────┐
│                        │
│     [ thumbnail ]      │   video: ffmpeg poster frame, duration overlay
│                        │
│  screenshot-09-14      │
│  2s ago · 412 KB       │
│                        │
│  Copy    Edit       ✕  │
└────────────────────────┘
```

- **Screenshot**: thumbnail is the PNG itself via `file://`.
- **Recording**: poster frame extracted once to
  `/tmp/qs-capture-poster-<basename>.jpg` with
  `ffmpeg -y -i <file> -vframes 1 -vf scale=<w>:-1`. Actions become Copy, Play
  (`xdg-open`), discard.
- **Copy** runs `wl-copy --type image/png < file`. Screenshots are already on
  the clipboard at capture time; the button is for re-copying after the
  clipboard has moved on.
- **Edit** runs `satty --filename <file> --output-filename <file>`.
- **Discard** deletes the file and dismisses. Destructive, so it follows the
  `RowActions` convention: a glyph that arms into a worded confirm.
- Auto-dismisses after `StyleCapture.previewTimeout` (8000ms). Hover pauses
  expiry, exactly as notifications do — the card is not a button.

### Tokens

`config/StyleCapture.qml`, per the Named Metric Rule — feature code references
domain meaning, never the equivalent primitive.

```qml
readonly property int bodyHeight: StylePopover.tileHeight
    + StylePopover.listRowHeight + StyleTokens.space8            // 110
readonly property int cardWidth: StyleNotification.width          // 360
readonly property int thumbnailHeight: 160
readonly property int cardHeight: thumbnailHeight
    + StylePopover.listRowHeight + StylePopover.rowHeight
    + StyleNotification.padding * 2                               // 296
readonly property int previewTimeout: 8000
readonly property int posterWidth: cardWidth
```

`cardWidth` borrows `StyleNotification.width` deliberately: the card shares the
bottom-right corner with the notification stack and a differing width would
read as a misalignment between two surfaces in the same column.

### Corner arbitration

Notifications already occupy bottom-right and stack upward. While a preview
card is visible, `NotificationWindow`'s bottom margin grows by the card's
height plus a gap, so the stack sits above the card rather than under it:

```qml
margins.bottom: StyleShellLayout.notificationBottomMargin
    + (Services.CaptureState.previewVisible
        ? StyleCapture.cardHeight + StyleNotification.gap
        : 0)
```

Without this the two surfaces overlap. This is the only coupling between the
two features.

## Script changes

### `system-screenshot`

Current behaviour is `grim | satty` for all three modes, so nothing is saved
until you export from the editor. New behaviour:

```
system-screenshot [region|window|output] [--edit]
```

- Default: `grim -g <geom> "$FILENAME"`, then `wl-copy --type image/png <
  "$FILENAME"`, then `quickshell ipc call capture saved "$FILENAME"`.
- `--edit`: the current `grim … | satty` pipe, unchanged.
- The IPC call is best-effort. Redirect its output and ignore failure — a dead
  shell must not fail the capture or print noise.

`trim_geometry` and the three mode branches are unchanged.

### `system-screenrecord`

- On start, after `mark_active`: `quickshell ipc call capture started`.
- On save, replace the entire `notify-send … --action=…` block with
  `quickshell ipc call capture saved "$final_file"`.
- Keep `notify-send` for **failures only** (`-u critical`). A failed capture
  has no file, so the card has nothing to show, and a critical toast is the
  right channel.
- `mark_active` / `mark_inactive` and the state file are untouched.

### `screenshots.lua`

`M.region`, `M.output`, `M.window` collapse to
`hl.dsp.exec_cmd(paths.shellQuote(paths.scripts.systemScreenshot) .. " <mode>")`.
The geometry helpers (`activeMonitorGeometry`, `activeWindowGeometry`) and the
inline `sh -c` strings are deleted — roughly 40 lines. `paths.lua` gains
`systemScreenshot = M.localBin .. "/system-screenshot"`; it currently lists
only `systemScreenrecord`.

This is what makes a keybind capture and a widget capture identical, preview
card included.

## Deletions

| What | Where | Why |
| --- | --- | --- |
| `notify-send` success block, ~15 lines | `system-screenrecord` | The card does this better. |
| Inline grim/slurp/satty commands, ~40 lines | `screenshots.lua` | Duplicates the script. |
| `isClipboardCopy`, `clipboardImagePath`, `clipboardSaveProcess`, `hasClipboardImage` | `NotificationCard.qml` | String-sniffing app names and bodies to guess a screenshot happened. A real channel replaces the guess. |
| `recordMenuEntries` (4 entries) | `ScreenRecord.qml` | Becomes two tiles plus a remembered toggle. |

Net effect on the shell is a reduction; the growth is in the two new capture
surfaces.

## Slices

Each is independently shippable and independently revertible.

1. **Seam and preview card.** `CaptureState`, the IPC handler, both script
   changes, `CapturePreviewWindow`/`Card`, corner arbitration, and the
   `NotificationCard` deletion. After this slice `Super+R` captures instantly,
   copies to the clipboard, and shows the card — the whole behavioural change,
   with the bar widget still record-only.
2. **Popover.** `CapturePopover`, `ScreenRecord.qml` → `Capture.qml`,
   `StyleCapture`, icons, `Bar.qml`.
3. **Cleanup.** `screenshots.lua` unification, `windowrules.lua`, `DESIGN.md`
   and `OVERVIEW.md` including the accepted divergence.

## Verification

`qmllint` is unusable in this repo (exits 255 on trivially valid files) and
`quickshell log` must be read with `-t <n>` or it serves stale lines from the
middle of a large file. So verification is behavioural, driven from a terminal
and confirmed with `grim`.

Per slice 1, for each of the five modes — `system-screenshot region`, `window`,
`output`, and `system-screenrecord region`, `fullscreen`:

1. File exists in the expected directory with the expected name pattern.
2. `wl-paste --list-types` includes `image/png` (screenshots only).
3. The preview card appears: `grim` the screen and read the PNG.
4. `--edit` still opens satty.
5. With quickshell killed, the capture still writes its file and the script
   exits 0.

Per slice 2, screenshot the popover on each segment and confirm the panel does
not change height between them — the failure the fixed-height rule exists to
prevent.

## Non-goals

- **Drag and drop to other applications.** The headline of CleanShot's own
  marketing, and genuinely hard from a layer-shell surface. If wanted, it is a
  spike of its own.
- **Capture history browser.** LATEST is one row. The filesystem and
  `folder_open` cover the rest.
- **Delay timer, scrolling capture, cloud upload, pinned floating shots.**
- **Rewriting the recorder's audio or encoder logic.** Untouched.
