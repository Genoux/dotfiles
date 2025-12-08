#!/bin/bash
# systemd-resolved configuration
# Enables systemd-resolved for proper DNS handling with NetworkManager

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

log_section "systemd-resolved"

# Enable systemd-resolved for proper DNS handling with NetworkManager
if ! systemctl is-enabled systemd-resolved.service &>/dev/null; then
    sudo systemctl enable --now systemd-resolved.service
    log_success "Enabled"
fi

