#!/bin/bash
# Bluetooth configuration
# Enables Bluetooth auto-start on boot

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

log_section "Bluetooth Configuration"

# Enable Bluetooth auto-start on boot
if [[ -f /etc/bluetooth/main.conf ]]; then
    log_info "Configuring Bluetooth to auto-enable on boot..."
    if grep -q "^AutoEnable=true" /etc/bluetooth/main.conf; then
        log_info "Bluetooth AutoEnable already configured"
    else
        sudo sed -i 's/^#\?AutoEnable=.*/AutoEnable=true/' /etc/bluetooth/main.conf
        log_success "Enabled Bluetooth auto-start"
    fi
else
    log_info "Bluetooth configuration file not found, skipping"
fi

log_success "Bluetooth configuration complete"

