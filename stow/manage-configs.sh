#!/bin/bash
# Creates/removes symlinks between dotfiles and system configs

case "$1" in
"install"|"link")
    if [[ -z "$2" ]]; then
        echo "Available configs:"
        ls -1 | grep -v manage-configs.sh | grep -v '\.sh$'
        echo "Usage: $0 install <config-name>"
        echo " or: $0 install all"
    elif [[ "$2" == "all" ]]; then
        echo "🔗 Installing all configs..."
        
        # Handle conflicts function (same as above)
        handle_conflicts() {
            local config="$1"
            local target_dir="$HOME/.config/$config"
            
            # Check if target exists and is not a symlink
            if [[ -e "$target_dir" && ! -L "$target_dir" ]]; then
                echo "⚠️  Found existing $target_dir"
                echo "📦 Backing up to $target_dir.bak"
                mv "$target_dir" "$target_dir.bak"
            fi
            
            # Check for other common locations
            case "$config" in
                "system")
                    for file in mimeapps.list user-dirs.dirs; do
                        if [[ -f "$HOME/.config/$file" && ! -L "$HOME/.config/$file" ]]; then
                            echo "⚠️  Found existing ~/.config/$file"
                            echo "📦 Backing up to ~/.config/$file.bak"
                            mv "$HOME/.config/$file" "$HOME/.config/$file.bak"
                        fi
                    done
                    ;;
                "zsh"|"bash")
                    for file in .zshrc .bashrc .profile; do
                        if [[ -f "$HOME/$file" && ! -L "$HOME/$file" ]]; then
                            echo "⚠️  Found existing ~/$file"
                            echo "📦 Backing up to ~/$file.bak"
                            mv "$HOME/$file" "$HOME/$file.bak"
                        fi
                    done
                    ;;
            esac
        }
        
        for config in */; do
            config=${config%/}
            [[ "$config" == "manage-configs.sh" ]] && continue
            echo "Linking $config..."
            
            # Handle conflicts before stowing
            handle_conflicts "$config"
            
            if stow -t "$HOME" "$config" 2>/dev/null; then
                echo "✅ Successfully linked $config"
            else
                echo "❌ Failed to link $config"
            fi
        done
        echo "🎉 All configs processed!"
    else
        echo "🔗 Linking $2..."
        
        # Handle conflicts by backing up existing files/directories
        handle_conflicts() {
            local config="$1"
            local target_dir="$HOME/.config/$config"
            
            # Check if target exists and is not a symlink
            if [[ -e "$target_dir" && ! -L "$target_dir" ]]; then
                echo "⚠️  Found existing $target_dir"
                echo "📦 Backing up to $target_dir.bak"
                mv "$target_dir" "$target_dir.bak"
            fi
            
            # Check for other common locations
            case "$config" in
                "system")
                    # Handle individual files that system config contains
                    for file in mimeapps.list user-dirs.dirs; do
                        if [[ -f "$HOME/.config/$file" && ! -L "$HOME/.config/$file" ]]; then
                            echo "⚠️  Found existing ~/.config/$file"
                            echo "📦 Backing up to ~/.config/$file.bak"
                            mv "$HOME/.config/$file" "$HOME/.config/$file.bak"
                        fi
                    done
                    ;;
                "zsh"|"bash")
                    # Handle dotfiles in home directory
                    for file in .zshrc .bashrc .profile; do
                        if [[ -f "$HOME/$file" && ! -L "$HOME/$file" ]]; then
                            echo "⚠️  Found existing ~/$file"
                            echo "📦 Backing up to ~/$file.bak"
                            mv "$HOME/$file" "$HOME/$file.bak"
                        fi
                    done
                    ;;
            esac
        }
        
        # Handle conflicts before stowing
        handle_conflicts "$2"
        
        # Now try to stow
        if stow -t "$HOME" "$2" 2>/dev/null; then
            echo "✅ Successfully linked $2"
            # Show the symlink that was created
            if [ -L "$HOME/.config/$2" ]; then
                echo "📁 Created: ~/.config/$2 -> $(readlink ~/.config/$2)"
            fi
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
                # Check for individual files that system config creates
                if [[ -L "$HOME/.config/mimeapps.list" || -L "$HOME/.config/user-dirs.dirs" ]]; then
                    linked=true
                fi
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
            echo "✅ Restored: $original"
        done
        echo "🎉 All backups restored!"
    else
        backup_file="$HOME/.config/$2.bak"
        original_file="$HOME/.config/$2"
        
        if [[ -e "$backup_file" ]]; then
            echo "🔄 Restoring $2..."
            rm -rf "$original_file" 2>/dev/null
            mv "$backup_file" "$original_file"
            echo "✅ Restored: $original_file"
        else
            echo "❌ No backup found for $2"
            echo "Expected: $backup_file"
        fi
    fi
    ;;

*)
    echo "⚙️ Config Manager"
    echo "Usage: $0 <command> [config]"
    echo
    echo "Commands:"
    echo " install <config> - Link config (auto-backup conflicts)"
    echo " install all     - Link all configs"
    echo " remove <config> - Unlink config"
    echo " remove all      - Unlink all configs"
    echo " restore <config> - Restore backed up config"
    echo " restore all     - Restore all backed up configs"
    echo " list           - Show available configs and backups"
    ;;
esac