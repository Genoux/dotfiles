#!/bin/bash
# Creates/removes symlinks between dotfiles and system configs
# Internal worker - called by dotfiles.sh

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
            [[ -e "$target" && ! -L "$target" ]] && rm -rf "$target" 2>/dev/null
            return 0
            ;;
        "backup")
            if [[ -e "$target" && ! -L "$target" ]]; then
                echo "📦 Backing up $target.bak"
                mv "$target" "$target.bak"
            fi
            return 0
            ;;
        "default")
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

# Handle config conflicts for different types
handle_config_conflicts() {
    local config="$1"
    
    case "$config" in
        "system")
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
            handle_conflict "$HOME/.config/$config" "~/.config/$config" || return 1
            ;;
    esac
    return 0
}

case "$1" in
"install"|"link")
    if [[ -z "$2" ]]; then
        ls -1 | grep -v manage-configs.sh | grep -v '\.sh$'
        exit 1
    elif [[ "$2" == "all" ]]; then
        echo "🔗 Installing all configs..."
        for config in */; do
            config=${config%/}
            [[ "$config" == "manage-configs.sh" ]] && continue
            
            echo "Linking $config..."
            if ! handle_config_conflicts "$config"; then
                echo "⏭️  Skipped $config"
                continue
            fi
            
            if stow -t "$HOME" "$config" 2>/dev/null; then
                echo "✅ Successfully linked $config"
            else
                echo "❌ Failed to link $config"
            fi
        done
        echo "🎉 All configs processed!"
    else
        echo "🔗 Linking $2..."
        if ! handle_config_conflicts "$2"; then
            echo "⏭️  Skipped $2"
            exit 0
        fi
        
        if stow -t "$HOME" "$2" 2>/dev/null; then
            echo "✅ Successfully linked $2"
            if [ -L "$HOME/.config/$2" ]; then
                echo "📁 Created: ~/.config/$2 -> $(readlink ~/.config/$2)"
            fi
        else
            echo "❌ Failed to link $2"
        fi
    fi
    ;;
"remove"|"unlink")
    if [[ -z "$2" ]]; then
        echo "Usage: $0 remove <config-name>"
        exit 1
    elif [[ "$2" == "all" ]]; then
        echo "🗑️ Removing all config links..."
        for config in */; do
            config=${config%/}
            [[ "$config" == "manage-configs.sh" ]] && continue
            echo "Unlinking $config..."
            if stow -D -t "$HOME" "$config" 2>/dev/null; then
                echo "✅ Successfully unlinked $config"
            else
                echo "⚠️ $config was not linked"
            fi
        done
        echo "🎉 All configs unlinked!"
    else
        echo "🗑️ Unlinking $2..."
        if stow -D -t "$HOME" "$2" 2>/dev/null; then
            echo "✅ Successfully unlinked $2"
        else
            echo "⚠️ $2 was not linked"
        fi
    fi
    ;;
"list")
    echo "📋 Available configs:"
    for config in */; do
        config=${config%/}
        [[ "$config" == "manage-configs.sh" ]] && continue
        
        linked=false
        case "$config" in
            "system")
                while IFS= read -r -d '' stow_file; do
                    relative_path="${stow_file#system/.config/}"
                    target_file="$HOME/.config/$relative_path"
                    if [[ -L "$target_file" ]]; then
                        linked=true
                        break
                    fi
                done < <(find system/.config -type f -print0 2>/dev/null)
                ;;
            "shell")
                if [[ -L "$HOME/.zshrc" || -L "$HOME/.profile" || -L "$HOME/.zprofile" ]]; then
                    linked=true
                fi
                ;;
            *)
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
                    echo "    📦 Has backups"
                fi
                ;;
            "shell")
                has_shell_backup=false
                for file in .zshrc .profile .zprofile; do
                    if [ -e "$HOME/$file.bak" ]; then
                        has_shell_backup=true
                        break
                    fi
                done
                if $has_shell_backup; then
                    echo "    📦 Has backups"
                fi
                ;;
            *)
                if [ -e "$HOME/.config/$config.bak" ]; then
                    echo "    📦 Has backups"
                fi
                ;;
        esac
    done
    ;;
"restore")
    if [[ -z "$2" ]]; then
        find "$HOME/.config" -name "*.bak" -type d -o -name "*.bak" -type f | sed 's|.*/||' | sort
        exit 1
    elif [[ "$2" == "all" ]]; then
        echo "🔄 Restoring all backups..."
        find "$HOME/.config" -name "*.bak" | while read backup; do
            original="${backup%.bak}"
            echo "Restoring $(basename "$original")..."
            rm -rf "$original" 2>/dev/null
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
    echo "Invalid command: $1"
    exit 1
    ;;
esac