#!/bin/bash
# sudoers configuration
# Configures sudo to only prompt for password once per boot (instead of per TTY/session)

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

log_section "sudoers"

# Install sudoers.d configuration files
if [[ -d "$SYSTEM_DIR/sudoers.d" ]]; then
    # Ensure sudoers.d directory exists
    sudo mkdir -p /etc/sudoers.d

    for file in "$SYSTEM_DIR/sudoers.d"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")

            # Validate sudoers syntax before installing
            if sudo visudo -c -f "$file" &>/dev/null; then
                # Install with correct permissions (0440)
                sudo install -m 0440 "$file" /etc/sudoers.d/
                log_success "$filename installed"
            else
                log_error "$filename has invalid sudoers syntax, skipping"
            fi
        fi
    done
fi
