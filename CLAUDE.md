# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Personal Arch Linux dotfiles repository featuring a complete system configuration with Hyprland window manager, AGS (Aylur's GTK Shell), and automated package/configuration management.

**Core Technologies:**
- **Window Manager**: Hyprland (Wayland compositor)
- **UI Shell**: AGS with TypeScript/JSX widgets
- **Theme System**: Base16 via flavours (single source of truth)
- **Config Management**: GNU Stow for symlinks
- **Package Management**: Custom tracking system with yay (AUR helper)
- **Shell Tools**: Bash scripts with gum for interactive TUI

## Essential Commands

### Daily Management
```bash
dotfiles                    # Interactive menu (recommended)
dotfiles status            # Show overall system state
dotfiles packages manage   # Add/remove packages interactively
dotfiles packages update   # System update (yay -Syu)
dotfiles config status     # Show stow link status
dotfiles theme apply       # Apply Base16 theme changes
```

### First-Time Installation
```bash
./install.sh              # Complete system setup
./install.sh --yes        # Skip confirmation prompts
```

### Package Management
```bash
# Interactive management (preferred)
dotfiles packages manage

# Hardware-specific packages
dotfiles packages hardware setup    # Detect and generate hardware package lists
dotfiles packages hardware install  # Install detected hardware packages

# Update system
dotfiles packages update
```

### Configuration Management
```bash
# Stow operations
dotfiles config link               # Link all configs
dotfiles config link <name>        # Link specific config (e.g., "hypr", "ags")
dotfiles config unlink <name>      # Unlink specific config
dotfiles config status             # Show link status
```

### Theme Management
```bash
dotfiles theme select              # Choose from available themes
dotfiles theme apply               # Regenerate all theme files from Base16 source
dotfiles theme install-gtk         # Install GTK theme (manual step)
```

### Hyprland Management
```bash
dotfiles hyprland setup           # Setup monitors + GPU config + plugins
```

## Architecture

### Main Entry Points

1. **`install.sh`** - First-time setup script
   - Installs bootstrap dependencies (stow, gum, jq)
   - Runs full installation phases (packages → config → post)
   - Sets up logging and error handling

2. **`dotfiles`** - Daily management CLI
   - Interactive menu system (default)
   - Subcommand routing (packages, config, theme, etc.)
   - Status display and operations

### Directory Structure

```
dotfiles/
├── install.sh              # Bootstrap script
├── dotfiles                # Main CLI
│
├── packages/               # Package definitions (.package files)
│   ├── arch.package        # Official Arch packages
│   ├── aur.package         # AUR packages
│   ├── zsh-plugins.package
│   ├── hyprland-plugins.package
│   └── hardware/           # Hardware-specific (auto-generated)
│
├── stow/                   # Config packages (GNU Stow)
│   ├── ags/                # AGS TypeScript configuration
│   ├── hypr/               # Hyprland configuration
│   ├── flavours/           # Base16 theme source (source of truth)
│   └── [23 total packages]
│
├── lib/                    # Core library modules
│   ├── package.sh          # Package management entry point
│   ├── package/            # Package operations (install, manage, update, sync)
│   ├── config.sh           # Stow operations
│   ├── theme.sh            # Theme management
│   ├── hyprland.sh         # Hyprland setup (monitors, GPU config)
│   ├── hyprland-plugins.sh # Plugin installation from official repo
│   ├── hardware-packages.sh # Hardware detection and package management
│   └── menu.sh             # Interactive menu system
│
├── install/                # Installation phase scripts
│   ├── helpers/            # Shared utilities (logging, errors, hardware detection)
│   ├── packages/           # Package installation
│   ├── config/             # Config deployment (stow + services)
│   ├── system/             # System-level configs
│   └── post/               # Post-install tasks
│
└── theme/                  # Theme metadata
    ├── THEME_REFERENCE.md  # Base16 color documentation
    └── gtk.json            # GTK theme metadata
```

### Key Architectural Patterns

#### Package Management System

**Package Files** (`.package` format):
- Plain text, one package per line
- Comments start with `#`
- Separate files for arch/aur/plugins
- Hardware packages auto-detected and generated

**Package Operations**:
- `lib/package/install.sh` - Installation logic
- `lib/package/manage.sh` - Interactive add/remove with gum
- `lib/package/update.sh` - System updates with conflict resolution
- `lib/package/sync.sh` - Deprecated (use manage instead)

**Hardware Detection**:
- `lib/hardware-packages.sh` detects GPU/CPU/device type
- Generates `packages/hardware/*.package` files
- Maps hardware to required packages

#### Theme System (Base16)

**Single Source of Truth**:
- `stow/flavours/.config/flavours/schemes/default/default.yaml`
- 16 color Base16 palette (base00-base0F)

**Auto-Generated Files** (via flavours templates):
- AGS styles (`~/.config/ags/style.scss`)
- Hyprland theme (`~/.config/hypr/theme.conf`)
- Kitty theme (`~/.config/kitty/theme.conf`)
- And more...

**Theme Operations**:
- `theme_apply()` - Regenerates all theme files from source
- `theme_select()` - Choose from available themes
- `apply_flavours_theme()` - Runs flavours with templates

#### Config Management (Stow)

**Stow Packages**: 23 packages in `stow/`
- Each package mimics home directory structure
- `stow -R` to link (restow)
- `stow -D` to unlink
- Special handling for `ags`, `scripts`, `applications`

**Link Management**:
- `config_link()` - Link single package
- `config_link_all()` - Link all packages
- `config_manage_interactive()` - Checkbox selection with gum
- `config_cleanup_orphans()` - Remove broken symlinks

#### Hyprland Setup

**Monitor Configuration**:
- `detect_monitors()` - Parse hyprctl output
- `generate_monitor_config()` - Create monitors.conf
- Auto-detects best resolution/refresh rate
- Device-aware scaling (laptop vs desktop)

**GPU Configuration**:
- `generate_gpu_config()` - Create gpu.conf
- Detects NVIDIA/AMD/Intel
- Sets appropriate env vars (WLR_*, LIBVA_*, etc.)
- DRI device detection

**Plugin Management**:
- Reads `packages/hyprland-plugins.package`
- Auto-installs from official hyprland-plugins repo
- Uses hyprpm (Hyprland plugin manager)
- Currently configured: hyprexpo only

#### Interactive Menu System

**Menu Framework** (`lib/menu.sh`):
- `choose_option()` - gum choose wrapper
- `run_operation()` - Run with spinner, handle errors
- `clear_screen()` - Clear with banner
- `pause()` - Wait for user

**Menu Hierarchy**:
```
Main Menu (show_menu in dotfiles)
├── System Status
├── Packages (packages_menu)
│   ├── Manage packages
│   ├── Hardware setup
│   └── Update system
├── Configs (config_menu)
│   ├── Manage links (interactive checkboxes)
│   ├── Link all
│   └── Unlink all
├── Themes (theme_menu)
│   ├── Select theme
│   └── GTK themes
├── Hyprland (hyprland_menu)
│   └── Setup Hyprland (monitors + GPU + plugins)
└── Others...
```

## Important Patterns and Conventions

### Package File Format
```bash
# Comments start with #
# One package per line, no version pinning
package-name-1
package-name-2

# Hardware-specific packages go in packages/hardware/
# and are auto-generated by hardware detection
```

### Stow Package Structure
```
stow/<package-name>/
├── .config/<app>/       # XDG config files
├── .local/bin/          # User scripts
├── .local/share/        # User data files
└── .[dotfile]           # Home directory dotfiles
```

### Theme Template Locations
- Source: `stow/flavours/.config/flavours/templates/`
- Config: `stow/flavours/.config/flavours/config.toml`
- Add custom templates here for new apps

### Helper Library Pattern
```bash
# All lib scripts check and source helpers if needed
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi
```

### Error Handling
- `graceful_error()` - Show error, don't exit
- `fatal_error()` - Show error, exit 1
- `setup_error_handling()` - Trap ERR signal
- All operations use `set -eEo pipefail` where appropriate

### Logging
- `init_logging()` - Start log file
- `log_section()`, `log_info()`, `log_success()`, `log_warning()`, `log_error()`
- `start_log_monitor()` - Live log tail in background
- `finish_logging()` - Close log file

## AGS (Aylur's GTK Shell)

AGS configuration uses TypeScript with JSX for widget templating.

**Important Context:**
- AGS uses Astal libraries for system integration
- Import via GObject introspection: `import Battery from "gi://AstalBattery"`
- State management: `createState()`, `createBinding()`
- Use Context7 MCP to search AGS/Astal documentation when needed
- Full guidelines in `.cursor/rules/astal.mdc`

**AGS-Specific Operations**:
- After stowing `ags` config, symlink is created: `~/.config/ags/node_modules/ags` → `/usr/share/ags/js`
- This provides TypeScript type definitions

## Gum Integration

This repository heavily uses `gum` (charmbracelet/gum) for interactive CLI.

**Common Patterns**:
```bash
# Choose from options
gum choose "option1" "option2" "option3"

# Filter/search
echo -e "item1\nitem2\nitem3" | gum filter

# Confirm action
gum confirm "Are you sure?" && do_action

# Multi-select with checkboxes
gum choose --no-limit --selected="item1" "item1" "item2" "item3"

# Input prompt
gum input --placeholder "Enter value"

# Styled output
gum style --bold --foreground 212 "Styled text"
```

**Key Usage in Code**:
- `choose_option()` - Wrapper in `lib/menu.sh`
- `filter_search()` - Wrapper for gum filter
- `confirm()` - Wrapper for gum confirm
- All menus use gum for selection

## Walker Application Launcher

Walker is the application launcher (similar to rofi/wofi).

**Key Points**:
- Installed via AUR: `walker` or `walker-bin`
- Config location: `stow/walker/.config/walker/`
- Can run as service: `walker --gapplication-service`
- Cache can be disabled in config: `[applications] cache = false`
- Guidelines in `.cursor/rules/walker.mdc`

## Special Considerations

### Hardware-Specific Packages
- Never edit `packages/hardware/*.package` files directly
- Run `dotfiles packages hardware setup` to regenerate
- Detection happens in `lib/hardware-packages.sh`

### Theme Modifications
- Always edit `stow/flavours/.config/flavours/schemes/default/default.yaml`
- Run `dotfiles theme apply` to regenerate all app-specific themes
- Never edit auto-generated theme files (they'll be overwritten)

### Stow Conflicts
- If stow reports conflicts, backup conflicting files first
- Use `config_cleanup_orphans()` to remove broken symlinks
- The `--adopt` flag moves existing files into stow dir (repo is source of truth)

### Hyprland Plugin Updates
- Plugins are built from source via hyprpm
- Hyprland version must match plugin compatibility
- Run `hyprpm update` manually if plugins break after Hyprland update

### Package Conflicts
- System automatically detects arch vs AUR conflicts
- If package moves between repos, conflict resolver prompts user
- Always commit package files after making changes

### Systemd Services
- User services in `stow/*/. config/systemd/user/`
- Started/enabled after config deployment
- Disabled automatically when unlinking configs

## Testing and Development

### Testing Package Changes
```bash
# Add package
dotfiles packages manage  # Select "Add package"

# View what would be installed
grep -v "^#" packages/arch.package packages/aur.package

# Install
dotfiles packages install
```

### Testing Config Changes
```bash
# Link single config
dotfiles config link <package-name>

# Check for conflicts
dotfiles config status

# Reload Hyprland if needed
hyprctl reload
```

### Testing Theme Changes
```bash
# Edit source
vim stow/flavours/.config/flavours/schemes/default/default.yaml

# Apply
dotfiles theme apply

# Restart apps to see changes
```

### Debugging
- Log file: `~/.local/share/dotfiles/logs/dotfiles-*.log`
- View live during operations: `tail -f ~/.local/share/dotfiles/logs/dotfiles-*.log`
- Use `gum pager` for scrollable log viewing

## Code Style

- Bash scripts use `#!/bin/bash` shebang
- Functions use snake_case naming
- Global variables use UPPER_CASE
- Always quote variables: `"$variable"`
- Use `[[ ]]` for conditions, not `[ ]`
- Prefer `$()` over backticks for command substitution
- Use `local` for function-scoped variables
- One command per line in pipe chains (for readability)
- Comments explain "why", not "what"
