# Dotfiles

Arch Linux with automated setup.

## Quick Start

```bash
git clone <your-repo> ~/dotfiles
cd ~/dotfiles
./dotfiles.sh
```

Choose option `1` for complete setup.

## What's Included

- **Packages**: Official + AUR packages with smart sync
- **Shell**: Zsh + Oh My Zsh + plugins  
- **Configs**: Hyprland, Kitty, Neovim, AGS, etc.
- **Themes**: GTK themes + app colors with GitHub repo management

## Main Script

Run `./dotfiles.sh` for interactive menu:

- `1` - Complete setup (everything)
- `2` - Smart package sync
- `3` - Package check/preview
- `z` - Shell setup (zsh + Oh My Zsh)
- `4` - Install specific config
- `5` - Install all configs
- `6` - Remove config
- `t` - Theme management
- `h` - Hyprland setup
- `s` - Status overview

## Structure

```
dotfiles/
├── dotfiles.sh           # Main script
├── packages.txt          # Official packages
├── aur-packages.txt      # AUR packages  
├── zsh-plugins.txt       # Zsh plugins
├── scripts/              # Setup scripts
├── stow/                 # Config files (managed by stow)
└── themes/               # Theme system
```

## Features

### Smart Package Management
- Auto-detects hardware (NVIDIA filtering)
- Syncs installed packages with package lists
- Preview changes before applying

### Theme System
- GitHub repo-based theme management
- Auto-installs all configured themes
- Smart theme name detection
- Use nwg-look for switching

### Config Management
- Stow-based symlink management
- Individual config install/remove
- Automatic Hyprland setup for monitors

## Adding Software

1. Install normally: `pacman -S app` or `yay -S app`
2. Run smart sync: `./dotfiles.sh` → `2`
3. Package lists update automatically

## Adding Configs

1. Copy config: `cp -r ~/.config/app stow/app/.config/`
2. Install: `./dotfiles.sh` → `4` → `app`
3. Now managed by dotfiles

## Fresh System Setup

1. Clone this repo
2. Run `./dotfiles.sh` → `1` (complete setup)
3. Reboot
4. Done

Simple and automated.