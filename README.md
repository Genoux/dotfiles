# Dotfiles

Personal Arch Linux dotfiles with Hyprland, AGS, and automated system configuration.

## Overview

This repository contains a complete system configuration for Arch Linux, featuring:

- **Window Manager**: Hyprland (Wayland compositor)
- **Shell**: AGS (Aylur's GTK Shell) - TypeScript-based widgets and UI
- **Terminal**: Kitty with custom theming
- **Theme System**: Base16 color schemes via flavours
- **Package Management**: Automated package tracking and installation
- **Config Management**: GNU Stow for dotfile symlinks

## Repository Structure

```
dotfiles/
├── install.sh           # Bootstrap script (first-time setup)
├── dotfiles             # Main CLI for daily management
│
├── bin/                 # Helper scripts
│   └── dotfiles-menu    # Desktop launcher for dotfiles manager
│
├── packages/            # Package definitions
│   ├── arch.package              # Official Arch packages
│   ├── aur.package               # AUR packages
│   ├── zsh-plugins.package       # Zsh plugin repositories
│   └── hyprland-plugins.package  # Hyprland plugin repositories
│
├── stow/                # Config packages (managed by GNU Stow)
│   ├── ags/             # AGS shell configuration
│   ├── hypr/            # Hyprland window manager
│   ├── kitty/           # Kitty terminal
│   ├── flavours/        # Base16 theme configuration
│   └── ...              # Other app configs
│
├── lib/                 # Library scripts
│   ├── package.sh       # Package management
│   ├── config.sh        # Stow operations
│   ├── theme.sh         # Theme application
│   └── ...              # Other modules
│
├── install/             # Installation phase scripts
│   ├── helpers/         # Shared utilities
│   ├── packages/        # Package installation
│   ├── config/          # Config deployment
│   └── post/            # Post-install tasks
│
├── system/              # System-level configs
│   ├── modules-load.d/  # Kernel modules
│   ├── systemd/         # Systemd units
│   └── udev/            # Udev rules
│
├── theme/               # Theme configuration
│   ├── THEME_REFERENCE.md  # Base16 color documentation
│   └── gtk.json            # GTK theme metadata
│
└── docs/                # Documentation
```

## Installation

### First-Time Setup

```bash
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The installation script will:
1. Install yay (AUR helper)
2. Install base system packages
3. Deploy configuration files via Stow
4. Install Hyprland plugins (auto-installs from official repo)
5. Apply themes
6. Configure shell and systemd services

### Selective Installation

Install specific components:

```bash
dotfiles packages install    # Install packages only
dotfiles config deploy       # Deploy configs only
dotfiles theme apply         # Apply theme only
```

## Usage

### Daily Management

```bash
dotfiles                     # Interactive menu
dotfiles packages status     # View package status
dotfiles packages manage     # Add/remove packages
dotfiles config status       # View config status
dotfiles theme apply         # Apply theme changes
```

### Theme Customization

Edit the Base16 color scheme:

```bash
vim stow/flavours/.config/flavours/schemes/default/default.yaml
dotfiles theme apply
```

See [theme/THEME_REFERENCE.md](theme/THEME_REFERENCE.md) for color documentation.

### Package Management

**Add packages:**
```bash
dotfiles packages manage
# Select "Add package" and choose type
```

**Remove packages:**
```bash
dotfiles packages manage
# Select "Remove package" and choose package
```

**Sync installed packages:**
```bash
dotfiles packages update
# Automatically updates package lists
```

## Theme System

Themes use the Base16 standard for consistent colors across all applications.

**Source of Truth**: `stow/flavours/.config/flavours/schemes/default/default.yaml`

**Auto-Generated Configs**:
- AGS styles (`~/.config/ags/style.scss`)
- Hyprland theme (`~/.config/hypr/theme.conf`)
- Kitty theme (`~/.config/kitty/theme.conf`)
- And more...

**GTK Theme**: Managed separately via `theme/gtk.json` (manual install required)

## Key Features

### Automated Package Tracking
- Tracks official and AUR packages separately
- Automatic conflict resolution
- Hardware-aware package filtering

### Smart Config Deployment
- GNU Stow for symlink management
- Backup existing configs before deployment
- Selective package deployment

### Base16 Theming
- Single source of truth for colors
- Auto-generates app-specific theme files
- Consistent colors across all applications

### Modular Scripts
- Clean separation of concerns
- Reusable library modules
- Comprehensive error handling

## Requirements

- Arch Linux
- Git
- Base-devel
- Internet connection

## Configuration

### Adding New Stow Packages

1. Create directory: `mkdir -p stow/myapp/.config/myapp`
2. Add config files to the appropriate structure
3. Deploy: `dotfiles config deploy`

### Adding Custom Templates

1. Add template to `stow/flavours/.config/flavours/templates/`
2. Register in `stow/flavours/.config/flavours/config.toml`
3. Apply: `dotfiles theme apply`

## Troubleshooting

**Stow conflicts:**
```bash
dotfiles config status       # View conflicts
# Backup and remove conflicting files, then deploy again
```

**Package conflicts:**
```bash
dotfiles packages update     # Auto-resolve conflicts
```

**Theme not applying:**
```bash
dotfiles theme apply
# Restart applications to see changes
```

## Credits

- [Hyprland](https://hyprland.org/) - Wayland compositor
- [AGS](https://github.com/Aylur/ags) - GTK shell for desktop widgets
- [flavours](https://github.com/misterio77/flavours) - Base16 theme manager
- [GNU Stow](https://www.gnu.org/software/stow/) - Symlink manager

## License

MIT License - See LICENSE file for details
