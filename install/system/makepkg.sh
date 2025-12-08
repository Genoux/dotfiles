#!/bin/bash
# makepkg configuration
# Disables debug packages in makepkg.conf (Arch-specific)

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
else
    # Ensure helpers are sourced even if flag is set (might be from different shell)
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "makepkg"

# makepkg.conf - disable debug packages
if [[ -f /etc/makepkg.conf ]]; then
    if grep -q "OPTIONS=.*debug.*" /etc/makepkg.conf; then
        sudo sed -i 's/\(OPTIONS=([^)]*\)debug\([^)]*)\)/\1!debug\2/' /etc/makepkg.conf
        log_success "Disabled debug packages"
    fi
fi

