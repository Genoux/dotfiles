## Agent Operating Guide

This repo is John's personal Arch Linux dotfiles. Treat it as a live desktop
configuration, not a generic template. Prefer small, reversible edits that match
the existing layout, naming, and shell style.

## First Principles

- Read the relevant files before changing them. This repo has many local
  conventions that are more important than generic defaults.
- Preserve user changes in the working tree. Never run destructive git commands
  or revert unrelated edits unless the user explicitly asks.
- Prefer descriptive names over clever or short names.
- Comments should explain why something exists, not restate what the code says.
- Keep files focused. Colocate related config with the package that owns it.
- Prefer declarative configuration, shell functions, package lists, and existing
  helpers over ad hoc imperative scripts.
- Do not create README or documentation files unless explicitly requested.

## Repo Map

- `stow/`: GNU Stow packages. Paths under each package mirror `$HOME`.
- `stow/hypr/.config/hypr/`: Hyprland, Hyprlock, Hypridle, wallpaper, monitors,
  input, window rules, animations, plugins, and user preferences.
- `stow/quickshell/.config/quickshell/`: Quickshell QML bottom bar, launcher,
  notifications, and shell services.
- `stow/ags/.config/ags/`: Legacy AGS/Astal GTK4 shell (retained in repo, not
  session-started).
- `stow/scripts/.local/bin/`: User-facing helper commands used by Hyprland,
  Quickshell, menus, wallpaper, screenshots, packages, and system workflows.
- `stow/*/.config/systemd/user/`: User services and timers started from the
  session or managed by the dotfiles tooling.
- `install/`: Install and setup entrypoints.
- `lib/`: Shared shell libraries for packages, stow config, Hyprland, hardware,
  themes, cleanup, updates, and menus.
- `packages/`: Package manifests for official Arch packages, AUR packages,
  Hyprland plugins, and shell plugins.
- `system/`: System-level config files copied or applied outside `$HOME`.

## Dotfiles CLI

The main local command is `dotfiles` from the repo root, symlinked into
`~/.local/bin/dotfiles`.

Important subcommands:

- `dotfiles status`: Show hardware, package, config, theme, shell, and Hyprland
  status.
- `dotfiles config link [name]`: Link all or one stow package.
- `dotfiles config unlink [name]`: Unlink stow packages.
- `dotfiles packages manage`: Interactive package management.
- `dotfiles packages update`: System update through `yay -Syu`.
- `dotfiles hyprland setup`: Configure Hyprland plugins and monitors when
  Hyprland is installed and running.
- `dotfiles theme status`: Show matugen and GTK theme status.

## Hyprland Architecture

`stow/hypr/.config/hypr/hyprland.lua` is intentionally small. It requires modules
in Hyprdots-like order (hardware → session → behavior → theme stack → startup →
overrides):

1. `gpu.lua`
2. `monitors.lua`
3. `env.lua`
4. `input.lua`
5. `misc.lua`
6. `plugins.lua`
7. `animations.lua`
8. `keybindings.lua`
9. `windowrules.lua`
10. `themes/common.lua`
11. `themes/theme.lua`
12. `themes/colors.lua`
13. `autostart.lua`
14. `userprefs.lua` (last — personal overrides)

Keep new Hyprland settings in the narrowest matching file. Only edit
`hyprland.lua` when changing require order or root-level permissions.

Hyprland ownership guide:

- Environment and session variables: `env.lua`.
- Monitors and generated display config: `monitors.lua`.
- GPU-specific output from detection: `gpu.lua`.
- Animations and layer animation rules: `animations.lua`.
- Input devices, gestures, touchpad, keyboard: `input.lua`.
- Misc desktop behavior (xwayland, binds, dwindle, debug): `misc.lua`.
- Keybindings and app variables: `keybindings.lua`.
- Window and workspace rules: `windowrules.lua`.
- Shared cursor/group visuals: `themes/common.lua` (requires `cursor.lua`).
- Layout, blur, shadows, gaps: `themes/theme.lua`.
- Border colors static fallback: `themes/colors.lua`.
- Personal overrides: `userprefs.lua`.
- Startup services and session bootstrap: `autostart.lua`.
- Wallpaper rotation: `system-pick-wallpaper` reads `~/.config/hypr/wallpapers/saves/`.
- awww transitions: `wallpaper-awww.conf`.
- Lock and idle behavior: Quickshell `lock.qml` via `system-lock`, `hypridle.conf`.

Use current Hyprland Lua syntax. Do not collapse the modular Lua files back into
legacy hyprlang one-line rule sprawl unless the user asks.

## Desktop Components

- Quickshell is the active shell and bar. It lives under
  `stow/quickshell/.config/quickshell/` (QML, hot-reload, no build step).
- Quickshell provides the app launcher, power menu, volume OSD, and
  notifications (Mako/Walker/Elephant removed from session startup).
- Do not restart Quickshell when changing wallpaper. Wallpaper or matugen theme
  updates are not a reason to bounce the shell here.
- Awww handles wallpaper transitions.
- Matugen generates theme assets. Do not reintroduce wallust or a dual
  matugen-plus-wallust terminal pipeline unless explicitly requested.
- Legacy AGS config remains under `stow/ags/` for reference; it is not started
  from Hyprland autostart and has no stowed `ags.service` unit.

## Learned User Preferences

- In Quickshell, system tray primary/left click should focus or raise the
  application. Secondary/right click opens the tray menu or popover.
- For the Quickshell media player, update the displayed MPRIS source from explicit
  interaction and playback-driven ordering, not from Hyprland window focus alone.
- Keep Hyprland visual tuning polished but practical: preserve the modular files,
  frosted-glass blur intent, rounded/bordered look, and readable grouping.
- Hypr config section headers use the two-line block-letter glyph comment style,
  not `# =====` three-line banners.
- Wallpaper workflow stays simple: rotate from `~/.config/hypr/wallpapers/saves/`
  only; no `wallpaper.conf`, rounded-corner post-processing, or similar hacks.
- The user is comfortable being challenged directly if an approach is wrong or
  likely to make the setup harder to maintain.
- Keep `keybindings.lua` thin: bind keys only; put reusable Hypr logic in `actions/*`
  modules.
- Anything that drives Hyprland (keybinds, widgets, scripts) should use the 0.55
  Lua dispatcher API (`hl.dsp`, `hl.bind`), not legacy `hyprctl dispatch` strings.
- Cursor theme should follow GTK/matugen theme install/switch, not stay hardcoded
  in `cursor.lua`.
- Session restore (`hyprsession`) should stay enabled by default when possible.

## Learned Workspace Facts

- `gpu.lua` and `monitors.lua` must stay at the Hypr config root; dotfiles
  detection and setup scripts expect those exact paths.
- Hypr `layerrule` for layer animation uses `hl.layer_rule({ no_anim = true })`,
  not legacy one-line `layerrule = noanim, ...`.
- Calcurse Google/iCal feed URLs live in gitignored
  `stow/calcurse/.config/calcurse/ics-feeds`; imports run via `hooks/pre-load`.
- Hypr `animations/` is kept with `.gitkeep` for Hyprdots layout parity; animation
  presets still live in `animations.lua` until split into that folder.
- Hyprland 0.55+ Lua configs use `hl.bind("MOD + key", hl.dsp.*)`; use lowercase
  letter keysyms for plain letter binds (uppercase often fails to match).
- On `hyprctl reload`, Lua `require()` is cached — clear affected `package.loaded`
  entries in `hyprland.lua` (especially `keybindings`) or binds can disappear.
- `hyprsession` 0.2.0 restore is incompatible with `hyprland.lua` (upstream issue
  #18); dotfiles use `system-hyprsession` to wrap restore as `hl.dsp.exec_cmd(...)`
  and re-detect live `HYPRLAND_INSTANCE_SIGNATURE`.
- `hyprsession.service` and `quickshell` start from Hyprland `autostart.lua`
  (not `WantedBy=graphical-session.target`); Quickshell starts first, then hyprsession
  restore runs asynchronously after an 8-second delay — this prevents the session save
  loop from blocking logout.
- Cursor theme: `lib/gtk.sh` writes only `theme` to
  `~/.config/hypr/generated/cursor.lua` on GTK install; cursor size stays in
  `cursor.lua`. Set `XCURSOR_THEME` with expanded `XCURSOR_PATH` (not literal
  `$HOME`).
- Hypr capability modules live under `stow/hypr/.config/hypr/actions/` (`launchers`,
  `paths`, `screenshots`, `windows`, `workspaces`); trigger via
  `hyprctl dispatch 'function() require("actions.*").fn() end'`.
- `config/workspaces.lua` drives workspace bind count and hyprexpo columns;
  `hooks.lua` handles hyprsession post-restore fixes;
  `smart-gaps.lua` adjusts gaps by window count and special workspace state.
- Window state cycle: `SUPER + u` via `actions.windows.cycleWindowState`.
- Quickshell bar TUIs use `ShellActions.launchOrFocus()` / `ShellActions.run()`.
- Quickshell needs `PATH` including `~/.local/bin` when started from systemd or
  Hyprland autostart.

## Shell And Script Style

- Most scripts are Bash. Match existing helper usage from `install/helpers/` and
  `lib/`.
- Prefer existing helpers such as logging, confirmation, config, package, theme,
  and Hyprland library functions.
- Gum is the preferred UI toolkit for interactive shell flows.
- Package operations use `pacman` for official packages and `yay` for AUR.
- Keep package declarations in `packages/*.package` when possible rather than
  burying new package names inside scripts.
- Quote paths and variables. Assume paths may contain spaces even if they
  usually do not.

## Systemd User Services

User services are stowed into `~/.config/systemd/user`. The setup flow runs
`systemctl --user daemon-reload`, enables services, and starts or restarts them.

Be careful with service changes:

- Preserve existing service names because Hyprland autostart and scripts call
  them directly.
- Prefer changing a service unit over adding process-management hacks elsewhere.
- If a service behavior changes, consider whether `autostart.conf`, scripts, or
  install setup also need updates.

## Validation Checklist

For Hyprland config changes:

- Check the touched file syntax against the current Hyprland wiki or installed
  command behavior when uncertain.
- Prefer `hyprctl reload` only when the user is in a running Hyprland session
  and the change is safe to reload.
- Use `hyprctl monitors`, `hyprctl clients`, or `hyprctl devices` for runtime
  evidence when debugging monitor, window, or input behavior.

For shell changes:

- Run `bash -n path/to/script` on edited Bash scripts.
- If a script uses sourced helpers, inspect the helper contract before changing
  arguments or return behavior.

For Quickshell changes:

- Edit QML under `stow/quickshell/.config/quickshell/`; Quickshell hot-reloads.
- Use `Colors.base**` from matugen-generated `Colors.qml`.
- Hyprland actions go through `config/ShellActions.qml`, not `hyprctl` subprocesses.

For legacy AGS changes (if ever needed):

- Run checks from `stow/ags/.config/ags/`.
- Prefer `pnpm run format:check` for formatting verification.
- Use current AGS/Astal GTK4 patterns and imports.

For package/config changes:

- Keep `install/`, `lib/`, `packages/`, and `stow/` consistent.
- Do not install, remove, or update real system packages unless the user asks.

## Research Rules

- For Hyprland, Hyprlock, AGS/Astal, and other fast-moving tools, check current
  docs when syntax or API behavior matters.
- Use MCP documentation servers when relevant and available.
- Prefer repo-local patterns over examples copied directly from documentation.

## Gentle AI

This repo uses [Gentle AI](https://github.com/Gentleman-Programming/gentle-ai) in
**workspace scope** for Cursor: SDD subagents, skills, Engram MCP, and the Gentleman
persona live under `.cursor/` and `.atl/` at the repo root (not in global
`~/.cursor/`).

Setup and refresh:

- `system-gentle-ai` or `system-gentle-ai setup` — Cursor workspace install, skill registry
- `system-gentle-ai sync claude-code` — sync Claude after upgrades (stow-aware)
- `gentle-ai skill-registry refresh --force` — after adding/removing skills
- `/sdd-init` in Cursor — initialize SDD project context

Claude settings live in stow; gentle-ai cannot sync symlinked files directly.
`system-gentle-ai sync claude-code` materializes, syncs, and re-stows automatically.
