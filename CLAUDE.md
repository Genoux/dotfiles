# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Personal Arch Linux dotfiles with automated system configuration, Hyprland desktop environment, and QuickShell/AGS-based UI components. This is a chaotic, personal-use repository subject to frequent changes.

## Primary CLI Tool

**`./dotfiles`** - Main management CLI for all dotfile operations

```bash
# Common commands
./dotfiles status                    # Show overall system state
./dotfiles install                   # Full installation
./dotfiles packages manage           # Interactive package management
./dotfiles packages update           # System update (yay -Syu)
./dotfiles config link [name]        # Stow configs (all or specific)
./dotfiles config unlink [name]      # Unstow configs
./dotfiles system apply              # Apply system-level configurations
./dotfiles cleanup all               # Run all cleanup tasks
./dotfiles menu                      # Interactive menu
```

## Architecture

### Package Management (`lib/package/`, `packages/`)

- **`packages/arch.package`** - Official Arch packages
- **`packages/aur.package`** - AUR packages
- **`packages/hyprland-plugins.package`** - Hyprland plugins
- **`packages/zsh-plugins.package`** - Zsh plugins

Core library modules:
- **`lib/package/core.sh`** - System preparation (yay, Node.js installation)
- **`lib/package/install.sh`** - Package installation orchestration
- **`lib/package/manage.sh`** - Interactive package management with gum
- **`lib/package/common.sh`** - Shared package utilities (dependency checks, AUR detection)
- **`lib/package/update.sh`** - System update logic
- **`lib/package/status.sh`** - Package status reporting

Package files are plain text, one package per line. Comments start with `#`.

### Configuration Management (`lib/config.sh`, `stow/`)

Uses GNU Stow for symlinking dotfiles. Each subdirectory in `stow/` is a stow package:

**Major packages:**
- `quickshell/` - QuickShell UI (QML-based, primary shell)
- `ags/` - AGS (Astal TypeScript, alternative shell)
- `hypr/` - Hyprland compositor config
- `shell/` - Zsh, shell configs
- `kitty/` - Kitty terminal
- `claude/`, `cursor/`, `zed/` - Editor configs

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
- `system/pacman/hooks/` - Pacman hooks for auto-sync
- `system/plymouth/` - Boot splash
- `system/modprobe.d/` - Kernel module configs

**Installation scripts** (`install/system/`):
- `setup.sh` - Main system config installer
- `keyd.sh`, `greeter.sh`, `plymouth.sh`, etc. - Individual installers

Apply with: `./dotfiles system apply`

### Hardware Management (`lib/hardware-packages.sh`, `packages/hardware/`)

Auto-detects hardware and installs appropriate drivers:
- GPU detection (AMD/NVIDIA/Intel)
- CPU microcode (AMD/Intel)
- Laptop-specific configs

```bash
./dotfiles hardware setup    # Detect and install drivers
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

QuickShell is Qt6/QML-based, not the Astal/TypeScript framework described in `.cursor/rules/astal.mdc`.

### AGS/Astal UI (`stow/ags/.config/ags/`)

TypeScript/JSX-based alternative shell using Astal framework. See `.cursor/rules/astal.mdc` for detailed development rules.

## Installation Flow

Full installation sequence (run via `./dotfiles install`):

1. **System preparation** (`install/system/setup.sh`)
   - Install yay (AUR helper)
   - Install Node.js
   - Configure system files

2. **Package installation** (`lib/package/install.sh`)
   - Sync package databases
   - Install official packages from `packages/arch.package`
   - Install AUR packages from `packages/aur.package`
   - Run package audit

3. **Configuration linking** (`lib/config.sh`)
   - Stow all packages from `stow/` to `$HOME`

4. **Post-installation** (`install/post/`)
   - Shell setup (zsh, oh-my-zsh, plugins)
   - Hyprland plugins
   - GTK theme installation

## Development Patterns

### Adding Packages

1. Add to `packages/arch.package` (official) or `packages/aur.package` (AUR)
2. Run `./dotfiles packages manage` for interactive install/sync

### Creating New Stow Package

1. Create directory in `stow/<name>/`
2. Mirror home directory structure (e.g., `stow/myapp/.config/myapp/config.toml`)
3. Link with `./dotfiles config link <name>`

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

### Working with AGS/Astal

Follow rules in `.cursor/rules/astal.mdc`:
- Use Context7 MCP to search AGS/Astal documentation
- Use functional TypeScript components with JSX
- Build: `meson setup build --wipe && meson install -C build`
- Import libraries via GObject introspection: `import Battery from "gi://AstalBattery"`

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
- QuickShell (primary) or AGS (alternative)

## Common Tasks

**Sync after manual package changes:**
```bash
./dotfiles packages manage
# Review missing/extra packages, choose to install or update package files
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
