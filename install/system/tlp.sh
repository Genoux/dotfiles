#!/bin/bash
# TLP Power Management Configuration
# Configures TLP for automatic laptop/desktop power optimization

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
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
tlp_config_changed=false
if [[ -d "$SYSTEM_DIR/tlp.d" ]]; then
    for file in "$SYSTEM_DIR/tlp.d"/*; do
        [[ -f "$file" ]] || continue
        filename=$(basename "$file")
        if install_file_if_changed "$file" "/etc/tlp.d/$filename"; then
            tlp_config_changed=true
            log_success "$filename"
        else
            log_info "$filename already up to date"
        fi
    done
fi

# Install udev rules for AMD GPU power management
if [[ -f "$SYSTEM_DIR/udev/rules.d/99-amd-power-save.rules" ]]; then
    if install_file_if_changed "$SYSTEM_DIR/udev/rules.d/99-amd-power-save.rules" /etc/udev/rules.d/99-amd-power-save.rules; then
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        log_success "Udev power management rules installed"
    else
        log_info "Udev power management rules already up to date"
    fi
fi

# Install modprobe configuration
if [[ -f "$SYSTEM_DIR/modprobe.d/power-save.conf" ]]; then
    if install_file_if_changed "$SYSTEM_DIR/modprobe.d/power-save.conf" /etc/modprobe.d/power-save.conf; then
        log_success "Kernel module power settings installed (reboot to fully apply)"
    else
        log_info "Kernel module power settings already up to date"
    fi
fi

# Install sysctl configuration
if [[ -f "$SYSTEM_DIR/sysctl.d/99-battery-optimize.conf" ]]; then
    if install_file_if_changed "$SYSTEM_DIR/sysctl.d/99-battery-optimize.conf" /etc/sysctl.d/99-battery-optimize.conf; then
        sudo sysctl --system >/dev/null 2>&1
        log_success "Sysctl battery optimizations applied"
    else
        log_info "Sysctl battery optimizations already up to date"
    fi
fi

# Enable TLP, restarting only when its configuration actually changed —
# `systemctl start` on an already-running unit is already a no-op, but a
# config change needs an explicit restart to take effect.
log_info "Enabling TLP service..."
sudo systemctl enable tlp.service
if $tlp_config_changed; then
    sudo systemctl restart tlp.service
else
    sudo systemctl start tlp.service
fi

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
