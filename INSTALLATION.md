# Dotfiles Installation Guide

## ISO-Like Installation System

This dotfiles manager now provides production-grade, plug-and-play installation with:

- ✅ **State Management** - Resume from failures
- ✅ **Atomic Operations** - Rollback on error
- ✅ **Dependency Resolution** - Correct installation order
- ✅ **Recovery Mode** - Fallback shells and auto-recovery
- ✅ **Hardware Detection** - Auto-configure drivers
- ✅ **Verification** - Comprehensive post-install checks

## Quick Start

### Fresh Installation

```bash
# Clone dotfiles
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run installation
./install.sh
```

The installer will:
1. Run pre-flight checks (network, disk space, conflicts)
2. Detect hardware (GPU, CPU, laptop vs desktop)
3. Install packages in dependency order
4. Link configurations atomically
5. Verify everything installed correctly
6. Create snapshots at each phase

### Resume After Failure

```bash
# If installation fails, check state
./install.sh --state

# Resume from failure point
./install.sh --resume
```

### Rollback to Previous State

```bash
# Rollback to specific phase
./install.sh --rollback=packages_official

# Or use interactive recovery
dotfiles recovery auto
```

## Installation Modes

### Standard Install
```bash
./install.sh
```

### Skip Packages (configs only)
```bash
./install.sh --skip-packages
```

### Skip Configs (packages only)
```bash
./install.sh --skip-configs
```

### Force Fresh Install
```bash
./install.sh --fresh
```

### Resume from Failure
```bash
./install.sh --resume
```

## Recovery Commands

### Check System Status
```bash
dotfiles status           # Overall system state
dotfiles verify           # Verify installation
dotfiles recovery status  # Recovery mode status
```

### Auto-Recovery
```bash
# Automatically detect and fix issues
dotfiles recovery auto
```

### Fallback Shell
```bash
# If QuickShell fails, use waybar
dotfiles recovery fallback

# Restore QuickShell when fixed
dotfiles recovery restore
```

### Emergency Mode
```bash
# Minimal working environment
dotfiles recovery emergency
```

## Installation Phases

The installer runs in phases, creating snapshots before each:

1. **preflight** - Check network, disk space, conflicts
2. **hardware_detect** - Detect GPU, CPU, generate driver configs
3. **system_prepare** - Install yay, Node.js, prepare system
4. **packages_official** - Install official Arch packages
5. **packages_aur** - Install AUR packages
6. **config_link** - Link dotfiles with stow
7. **system_config** - Apply system-level configs
8. **theme_setup** - Install themes and colors
9. **shell_setup** - Configure zsh/fish
10. **hyprland_setup** - Configure Hyprland
11. **verification** - Verify everything works

Each phase:
- Creates a snapshot before starting
- Can be resumed if it fails
- Can be rolled back individually

## Package Management

### View Status
```bash
dotfiles packages status
```

### Interactive Management
```bash
dotfiles packages manage
```

### Update System
```bash
dotfiles packages update
```

## Configuration Management

### Link All Configs
```bash
dotfiles config link
```

### Link Specific Config
```bash
dotfiles config link quickshell
dotfiles config link hypr
```

### Unlink Configs
```bash
dotfiles config unlink quickshell
```

### Config Status
```bash
dotfiles config status
```

## Hardware Management

### Detect and Install Drivers
```bash
dotfiles hardware setup
```

### Hardware Status
```bash
dotfiles hardware status
```

## Troubleshooting

### Installation Failed

1. Check what failed:
   ```bash
   ./install.sh --state
   ```

2. Check logs:
   ```bash
   tail -f ~/.dotfiles-install.log
   ```

3. Resume installation:
   ```bash
   ./install.sh --resume
   ```

4. If still failing, rollback and try fresh:
   ```bash
   ./install.sh --rollback=preflight
   ./install.sh --fresh
   ```

### QuickShell Not Working

1. Check status:
   ```bash
   dotfiles recovery status
   ```

2. Enable fallback:
   ```bash
   dotfiles recovery fallback
   ```

3. Verify QuickShell:
   ```bash
   quickshell --version
   ls ~/.config/quickshell/shell.qml
   ```

4. Restore when fixed:
   ```bash
   dotfiles recovery restore
   ```

### Missing Packages

1. Check what's missing:
   ```bash
   dotfiles verify
   dotfiles packages status
   ```

2. Install missing:
   ```bash
   dotfiles packages manage
   ```

### Config Links Broken

1. Check status:
   ```bash
   dotfiles config status
   ```

2. Relink:
   ```bash
   dotfiles config link
   ```

## Advanced Usage

### State Management

```bash
# Show current state
./install.sh --state

# Clear state (for fresh install)
./install.sh --fresh

# Resume from failure
./install.sh --resume
```

### Rollback

```bash
# Rollback to specific phase
./install.sh --rollback=packages_official

# This will:
# - Remove packages installed since that phase
# - Restore configs from snapshot
# - Reset state to that point
```

### Atomic Operations

The installer uses atomic operations for safety:

- **Snapshots** created before each phase
- **Backups** of existing configs before linking
- **Rollback** on any error
- **Verification** after each phase

### Dependency Resolution

Packages are installed in order:

1. Core (base, base-devel, git)
2. AUR Helper (yay)
3. System (kernel, firmware)
4. Drivers (GPU, CPU)
5. Display Server (Wayland, X11)
6. Compositor (Hyprland)
7. Shell UI (QuickShell, waybar)
8. Terminal (kitty)
9. Themes
10. Applications

Critical packages (hyprland, quickshell, kitty) are verified and block installation if they fail.

## One-Shot Installation on New Device

For true plug-and-play on a fresh Arch install:

```bash
# 1. Boot Arch ISO
# 2. Install base system
# 3. Clone dotfiles
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 4. Run one command
./install.sh

# That's it! The installer will:
# - Detect your hardware
# - Install all packages in order
# - Configure everything
# - Verify it all works
# - Give you a working desktop
```

If anything fails:
```bash
./install.sh --resume
```

The installer tracks everything and can resume from any failure point.

## Files and Directories

### State Files
- `~/.dotfiles-install-state.json` - Current installation state
- `~/.dotfiles-atomic-state.json` - Atomic transaction state
- `~/.dotfiles-recovery` - Recovery mode state

### Snapshots
- `~/.dotfiles-snapshots/` - Package and config snapshots
- `~/.dotfiles-backup/` - Backups of modified files

### Logs
- `~/.dotfiles-install.log` - Installation log
- `~/.dotfiles-daily.log` - Daily operations log

## Best Practices

### Before Installing
1. Commit any package file changes to git
2. Ensure network connectivity
3. Have at least 5GB free disk space
4. Close other package managers

### During Installation
1. Don't interrupt the installer
2. If you must stop, it can resume
3. Watch for errors in the output

### After Installation
1. Run `dotfiles verify` to check everything
2. Reboot to ensure autostart works
3. Check `dotfiles recovery status` if issues

### Maintenance
1. Update regularly: `dotfiles packages update`
2. Sync package lists: `dotfiles packages manage`
3. Clean up: `dotfiles cleanup all`
4. Verify health: `dotfiles verify`

## Support

If you encounter issues:

1. Check this guide
2. Run `dotfiles verify`
3. Check logs: `~/.dotfiles-install.log`
4. Use recovery: `dotfiles recovery auto`
5. Start fresh if needed: `./install.sh --fresh`
