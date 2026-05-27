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
- `stow/ags/.config/ags/`: AGS/Astal GTK4 shell. TypeScript, TSX widgets,
  services, and SCSS styles live here.
- `stow/scripts/.local/bin/`: User-facing helper commands used by Hyprland,
  AGS, menus, wallpaper, screenshots, packages, and system workflows.
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

`stow/hypr/.config/hypr/hyprland.conf` is intentionally small. It sources modules
in Hyprdots-like order (hardware → session → behavior → theme stack → startup →
overrides):

1. `gpu.conf`
2. `monitors.conf`
3. `env.conf`
4. `input.conf`
5. `misc.conf`
6. `plugins.conf`
7. `animations.conf`
8. `keybindings.conf`
9. `windowrules.conf`
10. `themes/common.conf`
11. `themes/theme.conf`
12. `themes/colors.conf`
13. `autostart.conf`
14. `userprefs.conf` (last — personal overrides)

Keep new Hyprland settings in the narrowest matching file. Only edit
`hyprland.conf` when changing source order or root-level permissions.

Hyprland ownership guide:

- Environment and session variables: `env.conf`.
- Monitors and generated display config: `monitors.conf` or templates.
- GPU-specific output from detection: `gpu.conf` or `gpu.conf.template`.
- Animations and layer animation rules: `animations.conf`.
- Input devices, gestures, touchpad, keyboard: `input.conf`.
- Misc desktop behavior (xwayland, binds, dwindle, debug): `misc.conf`.
- Keybindings and app variables: `keybindings.conf`.
- Window and workspace rules: `windowrules.conf`.
- Shared cursor/group visuals: `themes/common.conf` (sources `cursor.conf`).
- Layout, blur, shadows, gaps: `themes/theme.conf`.
- Border colors static fallback: `themes/colors.conf`.
- Personal overrides: `userprefs.conf`.
- Startup services and session bootstrap: `autostart.conf`.
- Wallpaper rotation: `system-pick-wallpaper` reads `~/.config/hypr/wallpapers/saves/`.
- awww transitions: `wallpaper-awww.conf`.
- Lock and idle behavior: `hyprlock.conf` and `hypridle.conf`.

Use current Hyprland syntax. This repo already uses modern `windowrule { ... }`
blocks and sourced modules; do not collapse it back into legacy one-line rule
sprawl unless the user asks.

## Desktop Components

- AGS/Astal is the shell and bar implementation. It is GTK4 and lives under
  `stow/ags/.config/ags/`.
- AGS scripts are managed with `pnpm` from the AGS config directory. Useful
  commands are `pnpm run format:check`, `pnpm run format`, and `pnpm run dev`.
- AGS does not reliably hot reload TS/SCSS. The config tooling may restart the
  `ags.service` when AGS files change.
- Do not restart AGS when changing wallpaper. Wallpaper or matugen theme updates
  are not a reason to bounce the shell here.
- Walker is the launcher/menu provider.
- Mako handles notifications.
- Awww handles wallpaper transitions.
- Matugen generates theme assets. Do not reintroduce wallust or a dual
  matugen-plus-wallust terminal pipeline unless explicitly requested.

## Learned User Preferences

- In AGS, system tray primary/left click should focus or raise the application.
  Secondary/right click opens the tray menu or popover.
- For the AGS media player, update the displayed MPRIS source from explicit
  interaction and playback-driven ordering, not from Hyprland window focus alone.
- Keep Hyprland visual tuning polished but practical: preserve the modular files,
  frosted-glass blur intent, rounded/bordered look, and readable grouping.
- Hypr config section headers use the two-line block-letter glyph comment style,
  not `# =====` three-line banners.
- Wallpaper workflow stays simple: rotate from `~/.config/hypr/wallpapers/saves/`
  only; no `wallpaper.conf`, rounded-corner post-processing, or similar hacks.
- The user is comfortable being challenged directly if an approach is wrong or
  likely to make the setup harder to maintain.

## Learned Workspace Facts

- `gpu.conf` and `monitors.conf` must stay at the Hypr config root; dotfiles
  detection and setup scripts expect those exact paths.
- Hypr `layerrule` for layer animation uses block syntax with `no_anim = on`,
  not legacy one-line `layerrule = noanim, ...`.
- Calcurse Google/iCal feed URLs live in gitignored
  `stow/calcurse/.config/calcurse/ics-feeds`; imports run via `hooks/pre-load`.
- Hypr `animations/` is kept with `.gitkeep` for Hyprdots layout parity; animation
  presets still live in `animations.conf` until split into that folder.

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

For AGS changes:

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
