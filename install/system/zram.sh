#!/bin/bash
# ZRAM Setup Script
# Installs and configures ZRAM compressed swap for better performance

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

log_section "ZRAM Compressed Swap"

# Install zram-generator if not already installed
if ! pacman -Qi zram-generator &>/dev/null; then
    log_info "Installing zram-generator..."
    sudo pacman -S --needed --noconfirm zram-generator
fi

# Copy ZRAM configuration
if [[ -f "$SYSTEM_DIR/systemd/zram-generator.conf" ]]; then
    sudo cp "$SYSTEM_DIR/systemd/zram-generator.conf" /etc/systemd/zram-generator.conf
    log_success "zram-generator.conf"
fi

# Reload systemd
sudo systemctl daemon-reload

# Start and enable ZRAM
sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
sudo systemctl enable systemd-zram-setup@zram0.service 2>/dev/null || true

# Verify ZRAM is working
if swapon --show | grep -q zram; then
    log_success "ZRAM active ($(swapon --show | grep zram | awk '{print $3}'))"
else
    log_warning "ZRAM will be active after reboot"
    mkdir -p "$HOME/.local/state/dotfiles"
    touch "$HOME/.local/state/dotfiles/.reboot_needed"
fi
