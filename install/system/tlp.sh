#!/bin/bash
# TLP Power Management Configuration
# Configures TLP for automatic laptop/desktop power optimization

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

log_section "TLP Power Management"

# Check if TLP is installed
if ! command -v tlp &>/dev/null; then
    log_warning "TLP not installed - install packages first"
    exit 0
fi

# Disable conflicting power-profiles-daemon
if systemctl is-active --quiet power-profiles-daemon; then
    log_info "Disabling conflicting power-profiles-daemon..."
    sudo systemctl stop power-profiles-daemon
    sudo systemctl disable power-profiles-daemon
    sudo systemctl mask power-profiles-daemon
    log_success "Disabled power-profiles-daemon"
fi

# Install TLP configuration
if [[ -d "$SYSTEM_DIR/tlp.d" ]]; then
    log_info "Installing TLP configuration..."
    sudo mkdir -p /etc/tlp.d
    sudo cp -r "$SYSTEM_DIR/tlp.d/"* /etc/tlp.d/
    log_success "TLP configuration installed"
fi

# Install udev rules for AMD GPU power management
if [[ -f "$SYSTEM_DIR/udev/rules.d/99-amd-power-save.rules" ]]; then
    log_info "Installing udev power management rules..."
    sudo mkdir -p /etc/udev/rules.d
    sudo cp "$SYSTEM_DIR/udev/rules.d/99-amd-power-save.rules" /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    log_success "Udev rules installed"
fi

# Install modprobe configuration
if [[ -f "$SYSTEM_DIR/modprobe.d/power-save.conf" ]]; then
    log_info "Installing kernel module power settings..."
    sudo mkdir -p /etc/modprobe.d
    sudo cp "$SYSTEM_DIR/modprobe.d/power-save.conf" /etc/modprobe.d/
    log_success "Kernel module settings installed"
fi

# Install sysctl configuration
if [[ -f "$SYSTEM_DIR/sysctl.d/99-battery-optimize.conf" ]]; then
    log_info "Installing sysctl battery optimizations..."
    sudo mkdir -p /etc/sysctl.d
    sudo cp "$SYSTEM_DIR/sysctl.d/99-battery-optimize.conf" /etc/sysctl.d/
    sudo sysctl --system >/dev/null 2>&1
    log_success "Sysctl settings applied"
fi

# Enable and start TLP
log_info "Enabling TLP service..."
sudo systemctl enable tlp.service
sudo systemctl start tlp.service

# Enable TLP RF switching (for WiFi/Bluetooth power management)
if systemctl list-unit-files | grep -q "systemd-rfkill"; then
    sudo systemctl mask systemd-rfkill.service
    sudo systemctl mask systemd-rfkill.socket
fi

log_success "TLP enabled and configured"

# Show TLP status
log_info "TLP Status:"
sudo tlp-stat -s | head -20

log_success "Power management configured successfully"
log_info "TLP will automatically optimize power based on AC/battery status"
log_info "Reboot recommended for all settings to take effect"
