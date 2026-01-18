#!/bin/bash
# Polkit rules configuration
# Installs polkit rules to allow user applications to run without authentication

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
else
    # Ensure helpers are sourced even if flag is set (might be from different shell)
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "polkit"

# Install polkit rules
if [[ -d "$SYSTEM_DIR/polkit-1/rules.d" ]]; then
    # Ensure polkit rules directory exists
    sudo mkdir -p /etc/polkit-1/rules.d

    for file in "$SYSTEM_DIR/polkit-1/rules.d"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            # Install with correct permissions (0644)
            sudo install -m 0644 "$file" /etc/polkit-1/rules.d/
            log_success "$filename installed"
        fi
    done
fi
