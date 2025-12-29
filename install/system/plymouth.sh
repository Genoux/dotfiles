#!/bin/bash
# Plymouth Boot Splash Setup
# Handles installation and configuration of Plymouth boot splash

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
else
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

# Status check function - returns 0 if properly configured
check_config_status() {
    # Only check if plymouth is installed
    pacman -Q plymouth &>/dev/null || return 1

    # Verify theme, hook, and theme selection
    [[ -d /usr/share/plymouth/themes/splash ]] && \
    grep -q "plymouth" /etc/mkinitcpio.conf 2>/dev/null && \
    [[ "$(plymouth-set-default-theme 2>/dev/null)" == "splash" ]]
}

# Only run main logic if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

log_section "Plymouth"

# Install plymouth if not already installed
if ! pacman -Q plymouth &>/dev/null; then
    log_info "Plymouth not installed, skipping configuration"
    exit 0
fi

# Copy splash theme to system
if [[ -d "$SYSTEM_DIR/plymouth/themes/splash" ]]; then
    sudo cp -r "$SYSTEM_DIR/plymouth/themes/splash" /usr/share/plymouth/themes/
    log_success "Plymouth theme installed"
fi

# Update mkinitcpio.conf to add plymouth hook
if [[ -f /etc/mkinitcpio.conf ]]; then
    # Check if plymouth hook already exists
    if ! grep -q "HOOKS=.*plymouth" /etc/mkinitcpio.conf; then
        # Add plymouth hook after systemd
        sudo sed -i 's/HOOKS=(base systemd /HOOKS=(base systemd plymouth /' /etc/mkinitcpio.conf
        log_success "Plymouth hook added to mkinitcpio"
    else
        log_info "Plymouth hook already configured"
    fi
fi

# Update bootloader entries to add kernel parameters
BOOT_ENTRIES="/boot/loader/entries"
if [[ -d "$BOOT_ENTRIES" ]]; then
    for entry in "$BOOT_ENTRIES"/*.conf; do
        [[ ! -f "$entry" ]] && continue
        [[ "$(basename "$entry")" == *"fallback"* ]] && continue

        # Check if already has plymouth parameters
        if ! grep -q "quiet splash" "$entry"; then
            # Add plymouth kernel parameters
            sudo sed -i '/^options/ s/$/ quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0/' "$entry"
            log_success "Kernel parameters added to $(basename "$entry")"
        else
            log_info "Kernel parameters already configured in $(basename "$entry")"
        fi
    done
fi

# Set plymouth theme to splash
CURRENT_THEME=$(plymouth-set-default-theme)
if [[ "$CURRENT_THEME" != "splash" ]]; then
    sudo plymouth-set-default-theme -R splash
    log_success "Plymouth theme set to splash (initramfs rebuilt)"
else
    log_info "Plymouth theme already set to splash"
fi

# Ensure Plymouth shows on shutdown/reboot
# Check if plymouth-quit-wait.service needs to be configured
#if systemctl list-unit-files plymouth-quit-wait.service &>/dev/null; then
#    sudo systemctl enable plymouth-quit-wait.service 2>/dev/null || true
#fi

log_success "Plymouth configured"

fi  # End of direct execution check
