---
name: quickshell
description: >-
  Quickshell QML desktop shell development for John's Hyprland bar. Use when
  editing .qml files, PanelWindow, Variants, WlrLayershell, Hyprland integration,
  system tray, MPRIS, Pipewire, singleton services, bar widgets, or quickshell
  config under ~/.config/quickshell.
---

# Quickshell Development

## Before You Code

1. Read `OVERVIEW.md` for this codebase's architecture and UX policies
2. Query **Context7** for upstream API (`/websites/quickshell_v0_3_0` on 0.3.x)
3. Match patterns in existing files — especially `bar/Bar.qml`, `config/Launchers.qml`, `components/IconButton.qml`

For detailed local reference, see [references.md](references.md).

## Entry Point Pattern

```qml
// shell.qml
import Quickshell
import qs.bar

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
        }
    }
}
```

## PanelWindow Bar Pattern

```qml
// bar/Bar.qml (abbreviated)
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.bar.widgets

PanelWindow {
    readonly property var hyprMonitor: Hyprland.monitorFor(screen)

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Style.barHeight
    color: Style.transparent

    // Left: Workspaces + SystemTray
    // Center: WindowTitle
    // Right: Privacy → Media → Volume → … → Dotfiles
}
```

Bottom bar uses `anchors.bottom` — layer defaults to top; set `WlrLayershell.layer: WlrLayer.Bottom` only if needed (check Context7 for your version).

## Singleton Service Pattern

```qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtCore

Singleton {
    readonly property string stateFilePath: `${StandardPaths.writableLocation(StandardPaths.HomeLocation)}/.local/state/dotfiles/updates.state`
    property int revision: 0

    FileView {
        path: root.stateFilePath
        watchChanges: true
        onLoadedChanged: root.revision++
        onFileChanged: { reload(); root.revision++ }
    }
}
```

Register singletons by placing `pragma Singleton` QML under `config/` or `services/`. Import as `import qs.services` / `import qs.config`.

## Hyprland Bridge (mandatory)

All compositor actions flow through `Launchers`:

| Need | Call |
|------|------|
| Launch or focus app | `Launchers.launchOrFocus(appId, cmd, fallback?)` |
| Focus window | `Launchers.focusWindow(selector)` |
| Switch workspace | `Launchers.switchWorkspace(id)` |
| Run script/TUI | `Launchers.run(["script-name"])` or `Quickshell.execDetached` |

Implementation dispatches to Lua:

```qml
Quickshell.execDetached([
    "hyprctl", "dispatch",
    `function() require("actions.launchers").launchOrFocus("app", "cmd") end`,
])
```

Workspace switch clears `package.loaded["actions.workspaces"]` before `require` — preserve this when touching workspace logic.

## Widget Checklist

When adding `bar/widgets/NewWidget.qml`:

- [ ] PascalCase filename matching component name
- [ ] Use `IconButton` / `Pill` / `InfoPill` from `qs.components` where appropriate
- [ ] Colors from `Colors.base**` — never hardcode theme colors
- [ ] Sizes/spacing from `Style.qml` constants
- [ ] Hyprland actions via `Launchers` only
- [ ] Per-monitor data: accept `hyprMonitor` prop from `Bar.qml`
- [ ] Polling: reuse `Style.pollIntervalFast|Normal|Slow`

## Process & Polling Patterns

| Pattern | Example | When |
|---------|---------|------|
| Long-running subprocess | `Privacy` + `privacy-monitor.sh` | Streaming state changes |
| One-shot poll + Timer | `Network`, `Temperature` | Periodic external data |
| Native Quickshell service | `Mpris`, `SystemTray`, `UPower` | Prefer bindings over bash |
| File watch | `Dotfiles` + `FileView` | External state files |

## Context7 Query Examples

Use these as starting queries (after `resolve-library-id`):

- `PanelWindow anchors implicitHeight WlrLayershell bottom bar`
- `Variants model Quickshell.screens delegate`
- `Process StdioCollector command polling`
- `FileView watchChanges path reload`
- `Hyprland monitorFor workspace`
- `SystemTray TrayItem activate secondaryActivate`
- `Mpris players canRaise raise`

## UX Policies

### Tray (`services/TrayFocus.qml`)

1. `item.activate()`
2. Try MPRIS raise (fuzzy match on tray id/title vs player identity)
3. Fall back to Hyprland window focus by class/title tokens

Middle click → `secondaryActivate()` (context menu). Do not change without explicit user request.

### Media player

Player selection: explicit user interaction key → playing player → first active → first registered. **Do not** switch player on Hyprland window focus.

## Theming

- matugen template: `stow/matugen/.config/matugen/templates/quickshell-colors.qml`
- Output: `~/.config/quickshell/Colors.qml` (gitignored, hot-reloaded)
- Hyprland layer blur: `windowrules.lua` namespace `^(quickshell)$`

## Validation

After changes:

- [ ] Bar renders on all monitors
- [ ] QML saves without Quickshell console errors
- [ ] Workspace pills scoped per monitor
- [ ] New widget uses `Launchers` for Hyprland (if applicable)
- [ ] Theme still reads `Colors.base**` correctly

Manual run: `quickshell` from `~/.config/quickshell`. Link via `dotfiles config link quickshell`.

## Engram

Save to `project: quickshell` after:

- Non-obvious Quickshell API behavior or version quirks
- New service/widget conventions established
- Bug fixes with root cause
