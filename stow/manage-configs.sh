#!/bin/bash
# Creates/removes symlinks between dotfiles and system configs
# Pure symlink management - no software installation

# Parse mode flags
MODE="default"  # default, force, backup
for arg in "$@"; do
    case "$arg" in
        --force)   MODE="force" ;;
        --backup)  MODE="backup" ;;
    esac
done

# Simple conflict handling based on mode
handle_conflict() {
    local target="$1"
    local description="$2"
    
    case "$MODE" in
        "force")
            # Just overwrite - that's what they want!
            [[ -e "$target" && ! -L "$target" ]] && rm -rf "$target" 2>/dev/null
            return 0
            ;;
        "backup")
            # Create .bak files
            if [[ -e "$target" && ! -L "$target" ]]; then
                echo "⚠️  Found existing $description"
                echo "📦 Backing up to $target.bak"
                mv "$target" "$target.bak"
            fi
            return 0
            ;;
        "default")
            # Ask user what to do
            if [[ -e "$target" && ! -L "$target" ]]; then
                echo "⚠️  Found existing $description"
                read -p "Overwrite? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm -rf "$target" 2>/dev/null
                    return 0
                else
                    echo "⏭️  Skipping $description"
                    return 1
                fi
            fi
            return 0
            ;;
    esac
}

# Simple conflict handling for different config types (shared function)
handle_config_conflicts() {
    local config="$1"
    
    case "$config" in
        "system")
            # Handle all files in system config dynamically
            while IFS= read -r -d '' stow_file; do
                relative_path="${stow_file#system/.config/}"
                target_file="$HOME/.config/$relative_path"
                handle_conflict "$target_file" "~/.config/$relative_path" || return 1
            done < <(find system/.config -type f -print0 2>/dev/null)
            ;;
        "shell"|"zsh"|"bash")
            for file in .zshrc .bashrc .profile .zprofile; do
                handle_conflict "$HOME/$file" "~/$file" || return 1
            done
            ;;
        *)
            # Default: check ~/.config/[config] directory
            handle_conflict "$HOME/.config/$config" "~/.config/$config" || return 1
            ;;
    esac
    return 0
}

case "$1" in
"install"|"link")
    if [[ -z "$2" ]]; then
        echo "Available configs:"
        ls -1 | grep -v manage-configs.sh | grep -v '\.sh$'
        echo "Usage: $0 install <config-name> [--force|--backup]"
        echo " or: $0 install all [--force|--backup]"
        echo ""
        echo "Modes:"
        echo "  --force   Overwrite everything (recommended)"
        echo "  --backup  Create .bak files before overwriting"
        echo ""
        echo "💡 For software setup (Oh My Zsh, Hyprland, etc.), use dedicated scripts:"
        echo "   dotfiles.sh → Shell Setup (Z) for Oh My Zsh + plugins"
        echo "   dotfiles.sh → Hyprland Setup (H) for monitors"
    elif [[ "$2" == "all" ]]; then
        echo "🔗 Installing all configs..."
        
        for config in */; do
            config=${config%/}
            [[ "$config" == "manage-configs.sh" ]] && continue
            
            echo "Linking $config..."
            
            # Handle conflicts based on mode
            if ! handle_config_conflicts "$config"; then
                echo "⏭️  Skipped $config"
                continue
            fi
            
            # Stow the config
            if stow -t "$HOME" "$config" 2>/dev/null; then
                echo "✅ Successfully linked $config"
            else
                echo "❌ Failed to link $config"
            fi
        done
        echo "🎉 All configs processed!"
        echo ""
        echo "💡 Next steps for full setup:"
        echo "   • Shell: dotfiles.sh → Shell Setup (Z) for Oh My Zsh + plugins"
        echo "   • Hyprland: dotfiles.sh → Hyprland Setup (H) for monitor config"
    else
        echo "🔗 Linking $2..."
        
        # Handle conflicts based on mode
        if ! handle_config_conflicts "$2"; then
            echo "⏭️  Skipped $2"
            exit 0
        fi
        
        # Now try to stow
        if stow -t "$HOME" "$2" 2>/dev/null; then
            echo "✅ Successfully linked $2"
            # Show the symlink that was created
            if [ -L "$HOME/.config/$2" ]; then
                echo "📁 Created: ~/.config/$2 -> $(readlink ~/.config/$2)"
            fi
            
            # Give helpful hints for configs that need additional setup
            case "$2" in
                "shell")
                    echo ""
                    echo "💡 For complete shell setup with Oh My Zsh + plugins:"
                    echo "   dotfiles.sh → Shell Setup (Z)"
                    ;;
                "hypr")
                    echo ""
                    echo "💡 For Hyprland monitor configuration:"
                    echo "   dotfiles.sh → Hyprland Setup (H)"
                    ;;
            esac
        else
            echo "❌ Failed to link $2"
            echo "💡 Run with verbose mode to see details:"
            echo "   cd ~/dotfiles/stow && stow -v -t ~ $2"
        fi
    fi
    ;;
"remove"|"unlink")
    if [[ -z "$2" ]]; then
        echo "Usage: $0 remove <config-name>"
    elif [[ "$2" == "all" ]]; then
        echo "🗑️ Removing all config links..."
        for config in */; do
            config=${config%/}
            [[ "$config" == "manage-configs.sh" ]] && continue
            echo "Unlinking $config..."
            if stow -D -t "$HOME" "$config" 2>/dev/null; then
                echo "✅ Successfully unlinked $config"
            else
                echo "⚠️ $config was not linked or already removed"
            fi
        done
        echo "🎉 All configs unlinked!"
    else
        echo "🗑️ Unlinking $2..."
        if stow -D -t "$HOME" "$2" 2>/dev/null; then
            echo "✅ Successfully unlinked $2"
        else
            echo "⚠️ $2 was not linked or already removed"
        fi
    fi
    ;;
"list")
    echo "📋 Available configs:"
    for config in */; do
        config=${config%/}
        [[ "$config" == "manage-configs.sh" ]] && continue
        
        # Check if config is linked (different logic for different types)
        linked=false
        case "$config" in
            "system")
                # Check if any system config files are linked
                while IFS= read -r -d '' stow_file; do
                    relative_path="${stow_file#system/.config/}"
                    target_file="$HOME/.config/$relative_path"
                    if [[ -L "$target_file" ]]; then
                        linked=true
                        break
                    fi
                done < <(find system/.config -type f -print0 2>/dev/null)
                ;;
            "zsh")
                # Check for zsh-related files
                if [[ -L "$HOME/.zshrc" || -L "$HOME/.config/zsh" ]]; then
                    linked=true
                fi
                ;;
            "bash")
                # Check for bash-related files  
                if [[ -L "$HOME/.bashrc" || -L "$HOME/.profile" ]]; then
                    linked=true
                fi
                ;;
            "shell")
                # Check for shell-related files
                if [[ -L "$HOME/.zshrc" || -L "$HOME/.profile" || -L "$HOME/.zprofile" ]]; then
                    linked=true
                fi
                ;;
            "applications")
                # Check for application desktop files
                if [[ -L "$HOME/.local/share/applications/reboot.desktop" || -L "$HOME/.local/share/applications/shutdown.desktop" ]]; then
                    linked=true
                fi
                ;;
            *)
                # Default: check for ~/.config/[config]/ directory
                if [ -L "$HOME/.config/$config" ]; then
                    linked=true
                fi
                ;;
        esac
        
        if $linked; then
            echo " ✅ $config (linked)"
        else
            echo " ⭕ $config (not linked)"
        fi
        
        # Check for backup files
        case "$config" in
            "system")
                if [[ -e "$HOME/.config/mimeapps.list.bak" || -e "$HOME/.config/user-dirs.dirs.bak" ]]; then
                    echo "    📦 Has backups in ~/.config/"
                fi
                ;;
            "shell")
                # Shell config backups are in home directory, not ~/.config/
                has_shell_backup=false
                for file in .zshrc .profile .zprofile; do
                    if [ -e "$HOME/$file.bak" ]; then
                        has_shell_backup=true
                        break
                    fi
                done
                if $has_shell_backup; then
                    echo "    📦 Has backup: ~/shell-files.bak"
                fi
                ;;
            *)
                if [ -e "$HOME/.config/$config.bak" ]; then
                    echo "    📦 Has backup: ~/.config/$config.bak"
                fi
                ;;
        esac
    done
    ;;
"restore")
    if [[ -z "$2" ]]; then
        echo "Usage: $0 restore <config-name>"
        echo "       $0 restore all"
        echo ""
        echo "Available backups:"
        find "$HOME/.config" -name "*.bak" -type d -o -name "*.bak" -type f | sed 's|.*/||' | sort
    elif [[ "$2" == "all" ]]; then
        echo "🔄 Restoring all backups..."
        find "$HOME/.config" -name "*.bak" | while read backup; do
            original="${backup%.bak}"
            echo "Restoring $(basename "$original")..."
            
            # Remove current symlink/file
            rm -rf "$original" 2>/dev/null
            
            # Restore backup
            mv "$backup" "$original"
            echo "✅ Restored $(basename "$original")"
        done
    else
        backup_file="$HOME/.config/$2.bak"
        original_file="$HOME/.config/$2"
        
        if [[ -e "$backup_file" ]]; then
            echo "🔄 Restoring $2..."
            rm -rf "$original_file" 2>/dev/null
            mv "$backup_file" "$original_file"
            echo "✅ Restored $2"
        else
            echo "❌ No backup found for $2"
        fi
    fi
    ;;
*)
    echo "Dotfiles Config Manager - Pure Symlink Management"
    echo ""
    echo "Usage: $0 <command> [config-name] [options]"
    echo ""
    echo "Commands:"
    echo "  install <config>   Create symlinks for config"
    echo "  install all        Create symlinks for all configs"
    echo "  remove <config>    Remove symlinks for config"
    echo "  remove all         Remove all symlinks"
    echo "  list               Show config status and backups"
    echo "  restore <config>   Restore backup for config"
    echo "  restore all        Restore all backups"
    echo ""
    echo "Options:"
    echo "  --force            Overwrite existing files"
    echo "  --backup           Create .bak files before overwriting"
    echo ""
    echo "Examples:"
    echo "  $0 install hypr --force     # Link Hyprland config, overwrite existing"
    echo "  $0 install all --backup     # Link all configs, backup existing files"
    echo "  $0 list                     # Show which configs are linked"
    echo ""
    echo "💡 For software setup, use dedicated scripts:"
    echo "   dotfiles.sh → Shell Setup (Z) for Oh My Zsh + plugins"
    echo "   dotfiles.sh → Hyprland Setup (H) for monitor configuration"
    echo "   dotfiles.sh → Package Sync for package installation"
    ;;
esac