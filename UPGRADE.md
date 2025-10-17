# Dotfiles System Upgrade

Your dotfiles have been completely restructured! 🎉

## What Changed

### Before

- Single monolithic `dotfiles.sh` with nested menus
- Package management had confusing bidirectional sync
- Two separate theme systems (system.sh + gtk.sh)
- Scripts scattered across multiple directories
- No proper logging
- Hard to maintain and extend

### After

- Clean separation: `install.sh` (fresh setup) + `dotfiles` (daily use)
- Modular library system (`lib/`)
- Unified theme management
- Beautiful TUI with `gum`
- Proper logging infrastructure
- Much easier to maintain and extend

## New Structure

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
│   ├── package.sh
│   ├── config.sh
│   ├── theme.sh
│   ├── shell.sh
│   └── hyprland.sh
├── stow/                   # Configurations (unchanged)
├── themes/                 # Themes (simplified)
└── migrations/             # Version upgrades
```

## Quick Start

The new CLI is super simple:

```bash
# Show the new menu
./dotfiles menu

# Or use commands directly
./dotfiles status
./dotfiles packages sync
./dotfiles theme switch dark
```

## Migration Notes

### Old Commands → New Commands

| Old                    | New                           |
| ---------------------- | ----------------------------- |
| `./dotfiles.sh` (menu) | `./dotfiles menu`             |
| Package sync option 1  | `./dotfiles packages sync`    |
| Package sync option 2  | `./dotfiles packages install` |
| Install config (menu)  | `./dotfiles config link`      |
| Theme management       | `./dotfiles theme switch`     |
| Shell setup            | `./dotfiles shell setup`      |
| Hyprland setup         | `./dotfiles hyprland setup`   |

### Removed Files

These files have been removed (still in git history if needed):

- `dotfiles.sh` - Use `./dotfiles` instead
- `themes/gtk.sh` - GTK theme is now configured once, no switching needed
- `themes/system.sh` - Replaced by `lib/theme.sh`
- All old scripts from `scripts/` - Replaced by `lib/` modules

**If you need the old code**, check git history: `git log --all --full-history -- deprecated/`

## New Features

1. **Better Logging**

   - Logs are in `~/.local/state/dotfiles/`
   - Separate install and daily operation logs
   - Easy to debug issues

2. **Hardware Detection**

   - Automatically filters NVIDIA packages based on your GPU
   - Laptop vs desktop detection for Hyprland scaling

3. **Interactive Menus**

   - Powered by `gum` for beautiful TUI
   - Cleaner, faster navigation
   - Better visual feedback

4. **Simplified Package Management**

   - `packages install` - Install from txt files
   - `packages sync` - Update txt files from system
   - `packages update` - System update (yay -Syu)
   - No more confusing prompts!

5. **Unified Theme System**
   - One command to switch all app themes
   - No more separate GTK theme management
   - Themes apply to: AGS, Hyprland, Kitty, SwayNC, etc.

## What to Do Now

1. **Test the new CLI:**

   ```bash
   ./dotfiles help
   ./dotfiles status
   ```

2. **Try the menu:**

   ```bash
   ./dotfiles menu
   ```

3. **Optional: Create a symlink for easier access:**

   ```bash
   sudo ln -s ~/dotfiles/dotfiles /usr/local/bin/dotfiles
   # Then use from anywhere:
   dotfiles status
   ```

4. **Optional: Add aliases to your shell:**
   ```bash
   alias df='dotfiles'
   alias dfs='dotfiles status'
   alias dfp='dotfiles packages'
   ```

## Logs

Check logs for any issues:

```bash
# Installation log
cat ~/.local/state/dotfiles/install.log

# Daily operations log
cat ~/.local/state/dotfiles/dotfiles.log
```

## Need Help?

- Run `./dotfiles help` for command reference
- Check `README.md` for full documentation
- Logs are your friend for debugging

## Feedback

If you find any issues or have suggestions, feel free to open an issue or submit a PR!

---

**Note:** The old `dotfiles.sh` is still there if you need it, but the new system is much better! Give it a try! 🚀
