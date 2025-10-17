# Dotfiles

Modern, modular dotfiles for Arch Linux with Hyprland, featuring a clean CLI interface powered by [gum](https://github.com/charmbracelet/gum).

## Features

- 🚀 **One-command installation** for fresh systems
- 🎯 **Clean CLI** for daily management
- 📦 **Declarative package management** with hardware filtering
- ⚙️ **Modular configs** using GNU Stow
- 🎨 **Unified theme system** across all applications
- 🐚 **Automated shell setup** (zsh + Oh My Zsh + plugins)
- 🖥️ **Hyprland monitor auto-configuration**
- 📊 **Beautiful TUI** with interactive menus

## Quick Start

### Fresh Installation

For a brand new system:

```bash
cd ~/dotfiles
./install.sh
```

This will:

1. Install all packages from `packages.txt` and `aur-packages.txt`
2. Link configurations via GNU Stow
3. Setup zsh with Oh My Zsh and plugins
4. Apply default theme
5. Configure Hyprland monitors

### Daily Usage

After installation, use the `dotfiles` command:

```bash
dotfiles menu          # Interactive menu
dotfiles status        # Show system state
```

## Commands

### Interactive Menu

```bash
dotfiles menu
# or just
dotfiles
```

Launches an interactive TUI menu with all options.

### System Status

```bash
dotfiles status
```

Shows complete system state: hardware, packages, configs, themes, shell, Hyprland.

### Package Management

```bash
dotfiles packages install   # Install from txt files → system
dotfiles packages sync      # Update txt files ← system
dotfiles packages update    # System update (yay -Syu)
dotfiles packages status    # Show package info
```

**Workflow:**

- Install a package: `pacman -S package`
- Sync to dotfiles: `dotfiles packages sync`
- Commit changes: `git add packages.txt && git commit`

### Configuration Management

```bash
dotfiles config link        # Link all configs
dotfiles config link ags    # Link specific config
dotfiles config unlink ags  # Unlink specific config
dotfiles config status      # Show what's linked
```

Configs are stored in `stow/` and linked to your home directory using GNU Stow.

### Theme Management

```bash
dotfiles theme list         # Show available themes
dotfiles theme switch dark  # Switch to dark theme
dotfiles theme status       # Show current theme
```

Themes are stored in `themes/` with variants like `dark/`, `light/`. Switching a theme applies it across AGS, Hyprland, Kitty, SwayNC, etc.

### Shell Management

```bash
dotfiles shell setup        # Setup zsh + Oh My Zsh + plugins
dotfiles shell status       # Show shell info
```

Plugins are defined in `zsh-plugins.txt` with format:

```
plugin-name:https://github.com/user/repo
```

### Hyprland

```bash
dotfiles hyprland setup     # Auto-configure monitors
dotfiles hyprland status    # Show Hyprland info
```

Auto-detects monitors and generates optimal configuration with refresh rates and scaling.

## Structure

```
dotfiles/
├── install.sh              # Fresh system installation
├── dotfiles                # Daily management CLI
├── install/                # Installation phases
│   ├── helpers/            # Shared utilities
│   ├── packages/           # Package installation
│   ├── config/             # Configuration setup
│   └── post/               # Post-install tasks
├── lib/                    # Operation libraries
│   ├── package.sh          # Package operations
│   ├── config.sh           # Config operations
│   ├── theme.sh            # Theme operations
│   ├── shell.sh            # Shell operations
│   └── hyprland.sh         # Hyprland operations
├── stow/                   # Configurations (GNU Stow)
│   ├── ags/
│   ├── hypr/
│   ├── kitty/
│   └── ...
├── themes/                 # Theme variants
│   ├── dark/
│   └── light/
├── migrations/             # Version upgrades
├── packages.txt            # Official packages
└── aur-packages.txt        # AUR packages
```

## Package Management

### Hardware Filtering

NVIDIA-specific packages are automatically filtered based on detected hardware:

- `nvidia`, `nvidia-utils`, `nvidia-settings`, etc.

### Adding Packages

1. Install: `sudo pacman -S package` or `yay -S aur-package`
2. Sync: `dotfiles packages sync`
3. Review changes in `packages.txt` / `aur-packages.txt`
4. Commit: `git add packages.txt aur-packages.txt && git commit`

### Installing on New System

```bash
./install.sh
# or
dotfiles install
```

Reads `packages.txt` and `aur-packages.txt`, filters by hardware, and installs missing packages.

## Theme System

Themes apply consistently across:

- AGS (status bar)
- Hyprland (colors)
- Kitty (terminal)
- SwayNC (notifications)
- SwayOSD (volume/brightness)
- Yazi (file manager)
- Starship (prompt)

### Adding a New App to Themes

1. **Edit `themes/config.json`** to add the mapping:

   ```json
   {
     "mappings": {
       "rofi.rasi": "~/.config/rofi/theme.rasi",
       "waybar.css": "~/.config/waybar/style.css"
     }
   }
   ```

2. **Add the theme file** to your theme directories:

   ```bash
   cp ~/.config/rofi/config.rasi themes/dark/rofi.rasi
   ```

3. **Switch theme** to apply:
   ```bash
   dotfiles theme switch dark
   ```

**That's it! No code changes needed.**

### Creating a New Theme

1. Create directory: `mkdir themes/mytheme`
2. Add theme files matching names in `themes/config.json`
3. Switch: `dotfiles theme switch mytheme`

## Shell Setup

The shell setup:

1. Installs Oh My Zsh (if not present)
2. Clones plugins from `zsh-plugins.txt`
3. Optionally sets zsh as default shell

### Adding Plugins

Edit `zsh-plugins.txt`:

```
zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions
zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting
```

Then run:

```bash
dotfiles shell setup
```

## Logging

Logs are stored in `~/.local/state/dotfiles/`:

- `install.log` - Full installation logs
- `dotfiles.log` - Daily operations logs

View recent logs:

```bash
tail -f ~/.local/state/dotfiles/dotfiles.log
```

## Requirements

### Required

- Arch Linux
- `bash`
- `git`
- `stow`
- `gum` (installed automatically)

### Optional

- `yay` (installed automatically for AUR packages)
- `hyprctl` (for Hyprland features)

## Tips

### Aliases

Add to your `.zshrc`:

```bash
alias df='dotfiles'
alias dfs='dotfiles status'
alias dfp='dotfiles packages'
alias dfc='dotfiles config'
alias dft='dotfiles theme'
```

### Auto-sync Packages

Create a hook to auto-sync after package installations:

```bash
# ~/.local/bin/post-package-hook
#!/bin/bash
cd ~/dotfiles && dotfiles packages sync
```

### Quick Theme Switch

Bind to a key in Hyprland:

```
bind = $mod, T, exec, dotfiles theme switch dark
```

## Troubleshooting

### Command not found: dotfiles

Ensure `~/dotfiles` is in your PATH or create a symlink:

```bash
sudo ln -s ~/dotfiles/dotfiles /usr/local/bin/dotfiles
```

### Package conflicts

If stow reports conflicts:

```bash
dotfiles config link --force   # Overwrite conflicts
```

### Theme not applying

Restart affected applications:

```bash
ags quit && ags
killall kitty && kitty
killall swaync && swaync
```

### Logs

Check logs for detailed error information:

```bash
cat ~/.local/state/dotfiles/dotfiles.log
cat ~/.local/state/dotfiles/install.log
```

## License

MIT

## Inspiration

Architecture inspired by [omarchy](https://github.com/basecamp/omarchy) - a beautifully designed dotfiles system with clean separation of concerns.
