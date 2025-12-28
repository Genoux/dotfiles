#!/bin/bash
# Keyd configuration installer
# Sets up application-level keybindings (Alt+C/V for copy/paste)

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

log_info "Configuring keyd..."

# Check if keyd is installed
if ! command -v keyd &>/dev/null; then
    log_warning "keyd is not installed. Install it with: sudo pacman -S keyd"
    log_info "Skipping keyd configuration"
    exit 0
fi

# Create keyd config directory if it doesn't exist
if [[ ! -d "/etc/keyd" ]]; then
    log_info "Creating /etc/keyd directory..."
    sudo mkdir -p /etc/keyd
fi

# Copy keyd config
KEYD_CONFIG="$SYSTEM_DIR/keyd/default.conf"
if [[ -f "$KEYD_CONFIG" ]]; then
    log_info "Installing keyd configuration..."
    sudo cp "$KEYD_CONFIG" /etc/keyd/default.conf
    sudo chmod 644 /etc/keyd/default.conf
    log_success "Keyd configuration installed"
    
    # Enable and start keyd service
    if systemctl is-enabled keyd.service &>/dev/null; then
        log_info "Reloading keyd configuration..."
        sudo keyd reload
    else
        log_info "Enabling and starting keyd service..."
        sudo systemctl enable --now keyd.service
    fi
    log_success "Keyd configuration applied"
else
    log_error "Keyd config file not found: $KEYD_CONFIG"
    exit 1
fi

log_success "Keyd configuration complete"

