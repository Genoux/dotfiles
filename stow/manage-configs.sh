#!/bin/bash
# Creates/removes symlinks between dotfiles and system configs

# Parse mode flags
MODE="default"  # default, force, backup, preview
for arg in "$@"; do
    case "$arg" in
        --force)   MODE="force" ;;
        --backup)  MODE="backup" ;;
        --preview) MODE="preview" ;;
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
        "preview")
            # Just show what would be overwritten
            if [[ -e "$target" && ! -L "$target" ]]; then
                echo "⚠️  Would overwrite: $description"
                return 1  # Don't actually install in preview mode
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
        echo "Usage: $0 install <config-name> [--force|--backup|--preview]"
        echo " or: $0 install all [--force|--backup|--preview]"
        echo ""
        echo "Modes:"
        echo "  --force   Overwrite everything (recommended)"
        echo "  --backup  Create .bak files before overwriting"
        echo "  --preview Show what would be overwritten (safe)"
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
            
            # Only actually stow if not in preview mode
            if [[ "$MODE" == "preview" ]]; then
                echo "👁️  Would link $config"
                continue
            fi
            
            if stow -t "$HOME" "$config" 2>/dev/null; then
                echo "✅ Successfully linked $config"
                
                # Auto-setup Hyprland configuration when installing hypr config in batch mode
                if [[ "$config" == "hypr" ]]; then
                    echo
                    echo "🚀 Auto-configuring Hyprland for your device..."
                    dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
                    hypr_setup_script="$dotfiles_dir/scripts/setup-hyprland.sh"
                    
                    if [[ -f "$hypr_setup_script" ]]; then
                        bash "$hypr_setup_script" setup --quiet
                    else
                        echo "⚠️  Hyprland setup script not found, skipping auto-configuration"
                    fi
                fi
            else
                echo "❌ Failed to link $config"
            fi
        done
        echo "🎉 All configs processed!"
    else
        echo "🔗 Linking $2..."
        
        # Install Oh My Zsh if needed (dependency for shell config)
        if [[ "$2" == "shell" && ! -d "$HOME/.oh-my-zsh" ]]; then
            echo "🚀 Installing Oh My Zsh (required for shell config)..."
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
            
            # Install required plugins
            echo "📦 Installing zsh plugins..."
            git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null || true
            git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null || true
            
            echo "✅ Oh My Zsh setup complete!"
        fi
        
        # Handle conflicts based on mode
        if ! handle_config_conflicts "$2"; then
            echo "⏭️  Skipped $2"
            exit 0
        fi
        
        # Only actually stow if not in preview mode
        if [[ "$MODE" == "preview" ]]; then
            echo "👁️  Would link $2"
            exit 0
        fi
        
        # Now try to stow
        if stow -t "$HOME" "$2" 2>/dev/null; then
            echo "✅ Successfully linked $2"
            # Show the symlink that was created
            if [ -L "$HOME/.config/$2" ]; then
                echo "📁 Created: ~/.config/$2 -> $(readlink ~/.config/$2)"
            fi
            
            # Auto-setup Hyprland configuration when installing hypr config
            if [[ "$2" == "hypr" ]]; then
                echo
                echo "🚀 Auto-configuring Hyprland for your device..."
                dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
                hypr_setup_script="$dotfiles_dir/scripts/setup-hyprland.sh"
                
                if [[ -f "$hypr_setup_script" ]]; then
                    bash "$hypr_setup_script" setup --quiet
                else
                    echo "⚠️  Hyprland setup script not found, skipping auto-configuration"
                    echo "💡 You can run Hyprland setup later with: dotfiles.sh -> Hyprland Setup"
                fi
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