#!/bin/bash

# Creates/removes symlinks between dotfiles and system configs

case "$1" in
    "install"|"link")
        if [[ -z "$2" ]]; then
            echo "Available configs:"
            ls -1 | grep -v manage-configs.sh | grep -v '\.sh$'
            echo "Usage: $0 install <config-name>"
            echo "   or: $0 install all"
        elif [[ "$2" == "all" ]]; then
            for config in */; do
                config=${config%/}
                [[ "$config" == "manage-configs.sh" ]] && continue
                echo "Linking $config..."
                stow -t "$HOME" "$config" 2>/dev/null || echo "  ⚠️ $config failed"
            done
        else
            echo "Linking $2..."
            stow -t "$HOME" "$2"
        fi
        ;;
    "remove"|"unlink")
        if [[ -z "$2" ]]; then
            echo "Usage: $0 remove <config-name>"
        elif [[ "$2" == "all" ]]; then
            for config in */; do
                config=${config%/}
                [[ "$config" == "manage-configs.sh" ]] && continue
                echo "Unlinking $config..."
                stow -D -t "$HOME" "$config" 2>/dev/null
            done
        else
            echo "Unlinking $2..."
            stow -D -t "$HOME" "$2"
        fi
        ;;
    "list")
        echo "Available configs:"
        for config in */; do
            config=${config%/}
            [[ "$config" == "manage-configs.sh" ]] && continue
            echo "  $config"
        done
        ;;
    *)
        echo "Config Manager"
        echo "Usage: $0 <command> [config]"
        echo
        echo "Commands:"
        echo "  install <config>  - Link config"
        echo "  install all       - Link all configs"
        echo "  remove <config>   - Unlink config"
        echo "  list              - Show available configs"
        ;;
esac

