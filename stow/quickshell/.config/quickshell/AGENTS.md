## Agent Operating Guide — Quickshell Bar

This directory is John's Quickshell desktop bar config (`~/.config/quickshell`). It is a
pure QML replacement for the former AGS bar inside the broader dotfiles repo. Treat it as
live desktop UI code, not a generic template.

See `OVERVIEW.md` for architecture, module map, and integration details.

## First Principles

- Read surrounding QML before editing. Match singleton patterns, imports, and widget order in `bar/Bar.qml`.
- Preserve user changes in the working tree. Never run destructive git commands unless explicitly asked.
- Hyprland window/workspace logic stays in Lua (`stow/hypr/.config/hypr/actions/*`). The bar dispatches through `config/Launchers.qml` only.
- `Colors.qml` is matugen-generated at `~/.config/quickshell/Colors.qml` — never stow or hand-edit it.
- Prefer small, reversible diffs. No build step; Quickshell hot-reloads QML edits.
- Do not create README or extra docs unless explicitly requested (`OVERVIEW.md` is the onboarding doc).

## Layout Map

| Path | Role |
|------|------|
| `shell.qml` | Entry: one `Bar` per screen via `Variants` |
| `bar/Bar.qml` | Bottom panel layout (left / center / right zones) |
| `bar/widgets/` | Feature widgets (workspaces, tray, media, system controls) |
| `components/` | Reusable UI (`IconButton`, `Pill`, `CavaVisualizer`, …) |
| `config/` | Singletons: `Style`, `Launchers`, `IconRegistry` |
| `services/` | Singleton state: `Privacy`, `TrayFocus`, `Network`, … |
| `assets/icons/` | Bundled SVG overrides (themed via `ColorOverlay`) |
| `assets/scripts/` | Long-running helpers (`privacy-monitor.sh`) |

Quickshell maps directories to modules: `qs.bar.widgets`, `qs.services`, `qs.config`, `qs.components`.

## Conventions

### Hyprland bridge

Use `Launchers.qml` for all compositor actions:

- `launchOrFocus` → `actions.launchers.launchOrFocus`
- `switchWorkspace` → `actions.workspaces.switch`
- `focusWindow` → `hl.dsp.focus`

Never duplicate window rules or workspace logic in QML.

### UX policies (carry from AGS)

- **Tray:** left/right click → `TrayFocus.activate()` (MPRIS raise, then Hyprland focus); middle click → `secondaryActivate()`.
- **Media:** `explicitPlayerKey` from user interaction drives displayed player — not Hyprland window focus alone.
- **Icons:** bundled SVGs in `assets/icons/` for bar-specific glyphs; everything else via `IconRegistry` → Freedesktop theme.

### Polling (`config/Style.qml`)

| Interval | Constant | Typical use |
|----------|----------|-------------|
| 1s | `pollIntervalFast` | Keyboard fallback |
| 5s | `pollIntervalNormal` | Network route |
| 30s | `pollIntervalSlow` | Temperature |
| 10 min | WeatherState | wttr.in |

### Theming

- matugen template: `stow/matugen/.config/matugen/templates/quickshell-colors.qml`
- Output: `~/.config/quickshell/Colors.qml` (base16 slots `base00`–`base0F`, shared with AGS)
- Link config: `dotfiles config link quickshell` triggers matugen output generation

## Related Dotfiles Paths

| Path | Role |
|------|------|
| `stow/hypr/.config/hypr/autostart.lua` | Starts `quickshell` via systemd on session start |
| `stow/hypr/.config/hypr/windowrules.lua` | Layer blur for `quickshell` namespace |
| `stow/scripts/.local/bin/` | TUIs and helpers launched from the bar |
| `stow/ags/.config/ags/` | Former bar — parity reference when porting behavior |

## Validation

- Edit QML → Quickshell hot-reloads (restart only if process/service is down).
- Theme change → run matugen / change wallpaper; bar picks up `Colors.qml` without restart.
- Hyprland integration → verify dispatches with `hyprctl` in a live session when uncertain.
- No npm/pnpm/format pipeline — match existing QML style manually.

## Gentle AI

Workspace-scoped Gentle AI lives under `.cursor/` (SDD agents, skills, Engram MCP, persona rule).

- `gentle-ai skill-registry refresh --force` — after skill or convention changes
- `/sdd-init` — already bootstrapped; Engram project key is `quickshell`
- GGA pre-commit: `.gga` + this file; use `/home/john/.local/bin/gga` explicitly

Parent dotfiles conventions: `/home/john/dotfiles/AGENTS.md`
