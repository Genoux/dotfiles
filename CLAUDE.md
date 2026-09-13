# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Personal Arch Linux dotfiles with automated system configuration, Hyprland desktop environment, and QuickShell-based UI components. This is a chaotic, personal-use repository subject to frequent changes.

## Primary CLI Tool

**`./dotfiles`** - Main management CLI for all dotfile operations

```bash
# Common commands
./dotfiles status                    # Show overall system state
./dotfiles install                   # Full installation
./dotfiles packages install          # Install missing packages from packages/*.package
./dotfiles packages custom           # Build custom GitHub PKGBUILD packages
./dotfiles packages update           # System update (yay -Syu)
./dotfiles config link [name]        # Stow configs (all or specific)
./dotfiles config unlink [name]      # Unstow configs
./dotfiles system apply              # Apply system-level configurations
./dotfiles cleanup all               # Run all cleanup tasks
./dotfiles menu                      # Interactive menu
```

## Architecture

### Package Management (`lib/package/`, `packages/`)

`packages/*.package` are the single source of truth for what gets installed —
nothing is auto-synced from the running system back into these files.

- **`packages/arch.package`** - Official Arch packages (hand-curated)
- **`packages/aur.package`** - AUR packages (hand-curated, prefer `-bin` variants)
- **`packages/custom.package`** - `owner/repo` GitHub repos with a PKGBUILD at
  their root (not on the AUR — e.g. locally maintained apps), built with
  `makepkg -si` via `./dotfiles packages custom`
- **`packages/hardware/*.package`** - Static, hand-curated GPU/CPU manifests
  (`nvidia.package`, `amd.package`, `intel.package`, `amd-ucode.package`,
  `intel-ucode.package`), selected — never regenerated — by `./dotfiles
  hardware setup`'s hardware detection
- **`packages/hyprland-plugins.package`** - Hyprland plugins
- **`packages/zsh-plugins.package`** - Zsh plugins

Core library modules:
- **`lib/package/core.sh`** - `ensure_yay_installed` (built from source, called only after the official phase's `-Syu`)
- **`lib/package/preflight.sh`** - Validates every package name against pacman/AUR before installing anything
- **`lib/package/install-official.sh`** - One batched `pacman -Syu --needed` for all official packages
- **`lib/package/install-aur.sh`** - One batched `yay -S --needed` for all AUR packages
- **`lib/package/install.sh`** - Package installation orchestration
- **`lib/package/custom.sh`** - Custom (GitHub PKGBUILD) package builds
- **`lib/package/update.sh`** - System update logic
- **`lib/package/status.sh`** - Package status reporting (read-only)

Package files are plain text, one package per line. Comments start with `#`.
To add or remove a package, edit `packages/arch.package` or `packages/aur.package`
directly, then run `./dotfiles packages install`.

### Configuration Management (`lib/config.sh`, `stow/`)

Uses GNU Stow for symlinking dotfiles. Each subdirectory in `stow/` is a stow package:

**Major packages:**
- `quickshell/` - QuickShell UI (QML-based, primary shell)
- `hypr/` - Hyprland compositor config
- `shell/` - Zsh, shell configs
- `kitty/` - Kitty terminal
- `claude/`, `zed/` - Editor configs
- `icons/` - App icon overrides layered onto the MacTahoe icon theme

Commands:
```bash
./dotfiles config link              # Link all configs
./dotfiles config link quickshell   # Link specific package
./dotfiles config unlink quickshell # Unlink specific package
./dotfiles config status            # Show link status
```

### System Configuration (`system/`, `install/system/`)

System-level configs requiring root access:

**Config directories:**
- `system/keyd/` - Keyboard remapping (keyd)
- `system/systemd/` - Systemd units, sleep config, zram
- `system/greetd/` - Login manager (greetd + sysc-greet)
- `system/tlp.d/` - Power management (TLP)
- `system/udev/` - udev rules (ESP32, AMD power save)
- `system/pacman/hooks/` - Pacman cache-cleanup hook only (package lists are never auto-synced — see Package Management)
- `system/plymouth/` - Boot splash
- `system/modprobe.d/` - Kernel module configs

**Installation scripts** (`install/system/`):
- `setup.sh` - Main system config installer
- `keyd.sh`, `greeter.sh`, `plymouth.sh`, etc. - Individual installers

Apply with: `./dotfiles system apply`

### Hardware Management (`lib/hardware-packages.sh`, `packages/hardware/`)

Static, hand-curated manifests selected (never generated) by detected
hardware — generating from what's already installed produced empty
manifests on a fresh machine:
- `packages/hardware/nvidia.package`, `amd.package`, `intel.package` - GPU driver packages, selected by `lspci`-based GPU detection
- `packages/hardware/amd-ucode.package`, `intel-ucode.package` - CPU microcode, selected by `/proc/cpuinfo` vendor detection
- Laptop-specific configs

```bash
./dotfiles hardware setup    # Detect hardware, install the selected manifests
./dotfiles hardware status   # Show hardware info
```

### QuickShell UI (`stow/quickshell/.config/quickshell/`)

QML-based Wayland shell components:

**Structure:**
- `shell.qml` - Main entry point
- `bar/` - Top bar components
- `launcher/` - Application launcher
- `power/` - Power menu
- `notifications/` - Notification center
- `osd/` - On-screen display
- `services/` - Backend services (Battery, Network, etc.)
- `components/` - Reusable UI components
- `config/` - Style, icons, actions

QuickShell is Qt6/QML-based (Qt6/QML, not TypeScript).

## Installation Flow

Full installation sequence (run via `./dotfiles install`), in the actual
phase order (`install.sh`):

1. **Hardware detection** (`lib/hardware-packages.sh`) - detect GPU/CPU only, no pacman/yay calls, so it can safely run before preflight
2. **Preflight** (`lib/package/preflight.sh`) - enable multilib, sync the pacman DB, validate every official/AUR package name (including the hardware manifests hardware detection just selected)
3. **Official packages** (`lib/package/install-official.sh`) - one `pacman -Syu --needed` for `packages/arch.package` + the selected `packages/hardware/*.package`
4. **AUR packages** (`lib/package/install-aur.sh`) - one `yay -S --needed` for `packages/aur.package` (+ any hardware AUR manifests)
5. **Configuration + system** (`install/config/all.sh`) - stow all packages from `stow/` to `$HOME`, then `install/system/*.sh` (network, makepkg, hardware driver post-install setup, etc.), shell/theme/Hyprland setup
6. **Custom packages** (`lib/package/custom.sh`) - GitHub PKGBUILD repos from `packages/custom.package`, built last via `gh` + `makepkg -si`
7. **Verification** (`lib/package/verify.sh`)

## Development Patterns

### Adding Packages

1. Add to `packages/arch.package` (official), `packages/aur.package` (AUR),
   or `packages/custom.package` (`owner/repo` GitHub PKGBUILD, not on the AUR)
2. Run `./dotfiles packages install` (or `packages custom` for the GitHub list)

### Creating New Stow Package

1. Create directory in `stow/<name>/`
2. Mirror home directory structure (e.g., `stow/myapp/.config/myapp/config.toml`)
3. Link with `./dotfiles config link <name>`

### Overriding an App Icon

App icons are never special-cased in QML. QuickShell resolves them through
`IconRegistry` -> the app's `.desktop` `Icon=` name -> `Quickshell.iconPath()`,
so an override placed in the icon theme applies everywhere at once: bar,
launcher, tray and notifications.

1. Read the name the app declares: `Icon=` in `/usr/share/applications/<app>.desktop`
2. Drop a PNG under that exact name in `stow/icons/.local/share/icons/MacTahoe/apps/scalable/`
3. `./dotfiles config link icons`

The package holds only the overrides, never a copy of the theme. Qt resolves
`.png` before `.svg` within a theme directory, so a PNG wins over the vendor
`.svg` sitting beside it and the vendor tree is left untouched. All three
MacTahoe variants share one real `apps/scalable` directory, so a single file
covers `MacTahoe`, `-dark` and `-light`.

Reinstalling MacTahoe over `~/.local/share/icons` replaces the stow symlinks
with vendor files; re-run `./dotfiles config link icons` to restore them.

### Modifying System Configs

1. Edit files in `system/<subsystem>/`
2. Update corresponding script in `install/system/<subsystem>.sh` if needed
3. Apply with `./dotfiles system apply` or `sudo install/system/<subsystem>.sh`

### Working with QuickShell

QuickShell files are QML (Qt6). Key patterns:
- Import services: `import "qrc:/io/quickshell/services/..."`
- Component structure: `Item { id: root; ... }`
- Signal handling: `onSignal: { ... }`
- Property bindings: `property: value`

Build/reload not typically needed - QuickShell watches files.

## Logging

All operations log to `~/.dotfiles-install.log` or `~/.dotfiles-daily.log`. Helpers in `install/helpers/logging.sh` provide:
- `log_info`, `log_warning`, `log_error`
- `run_command_logged` - Execute and log commands
- Real-time log monitoring with gum

## Dependencies

**Required system tools:**
- `gum` - Interactive CLI components (charmbracelet/gum)
- `stow` - Symlink manager
- `yay` - AUR helper
- `tte` (python-terminaltexteffects) - Banner animations

**Runtime requirements:**
- Arch Linux (pacman-based)
- Hyprland compositor
- QuickShell

## Common Tasks

**Install after editing package lists:**
```bash
./dotfiles packages install
# Edit packages/arch.package or packages/aur.package by hand first — nothing
# auto-syncs installed packages back into these files.
```

**Update system:**
```bash
./dotfiles packages update
```

**Add new stow config:**
```bash
mkdir -p stow/myapp/.config/myapp
cp /path/to/config stow/myapp/.config/myapp/
./dotfiles config link myapp
```

**Clean up system:**
```bash
./dotfiles cleanup all              # All cleanup tasks
./dotfiles cleanup orphans          # Remove orphaned packages
./dotfiles cleanup cache            # Clean pacman cache
./dotfiles cleanup aur              # Clean AUR build cache
```

## Known Issues

- **Laptop touchpad i2c-hid glitch**: Trackpad may die mid-session (ELAN i2c_hid_get_input error). Fix requires full poweroff, not reboot. (See `memory/project_laptop_touchpad_i2c_glitch.md`)
- Hardware-specific packages commented in `arch.package` - run `./dotfiles hardware setup` for auto-detection
