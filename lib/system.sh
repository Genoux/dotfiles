#!/bin/bash
# System configuration operations

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Apply system configurations
system_apply() {
    log_section "Applying System Configurations"

    # Validate and cache sudo access at the beginning
    if ! sudo -v; then
        log_error "Failed to authenticate with sudo"
        return 1
    fi

    # Keep sudo timestamp fresh in the background
    while true; do
        sudo -n true
        sleep 60
        kill -0 $$ 2>/dev/null || exit
    done &
    SUDO_KEEPALIVE_PID=$!

    # Cleanup function
    cleanup_sudo() {
        kill $SUDO_KEEPALIVE_PID 2>/dev/null || true
    }
    trap cleanup_sudo EXIT

    # Run individual system configuration scripts
    bash "$DOTFILES_DIR/install/system/systemd-sleep.sh"
    bash "$DOTFILES_DIR/install/system/logind.sh"
    bash "$DOTFILES_DIR/install/system/makepkg.sh"
    bash "$DOTFILES_DIR/install/system/timezone.sh"
    bash "$DOTFILES_DIR/install/system/systemd-resolved.sh"
    bash "$DOTFILES_DIR/install/system/bluetooth.sh"
    bash "$DOTFILES_DIR/install/system/esp32.sh"
    bash "$DOTFILES_DIR/install/system/app-launcher.sh"
    bash "$DOTFILES_DIR/install/system/greeter.sh"

    # Cleanup
    cleanup_sudo

    echo
    log_success "System configuration complete"

    # Check if reboot is needed and prompt (only if not in full install)
    if [[ -f "$HOME/.local/state/dotfiles/.reboot_needed" && -z "${FULL_INSTALL:-}" ]]; then
        echo
        log_warning "Reboot required to apply changes"
        if confirm "Reboot now?"; then
            rm -f "$HOME/.local/state/dotfiles/.reboot_needed"
            sudo systemctl reboot
        fi
    fi
}

# Show system status
system_status() {
    log_section "System Status"

    # makepkg.conf debug status
    if [[ -f /etc/makepkg.conf ]]; then
        if grep -q "OPTIONS=.*!debug.*" /etc/makepkg.conf; then
            show_info "makepkg debug" "disabled ✓"
        else
            show_info "makepkg debug" "enabled (should disable)"
        fi
    else
        show_info "makepkg.conf" "not found"
    fi

    # systemd sleep config
    local sleep_configs=0
    if [[ -d /etc/systemd/sleep.conf.d ]]; then
        sleep_configs=$(find /etc/systemd/sleep.conf.d -type f 2>/dev/null | wc -l)
    fi
    show_info "systemd sleep configs" "$sleep_configs installed"

    # systemd logind config
    local logind_configs=0
    if [[ -d /etc/systemd/logind.conf.d ]]; then
        logind_configs=$(find /etc/systemd/logind.conf.d -type f 2>/dev/null | wc -l)
    fi
    show_info "systemd logind configs" "$logind_configs installed"
}
