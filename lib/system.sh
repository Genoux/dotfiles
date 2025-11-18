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

# Configure laptop-specific settings
configure_laptop_settings() {
    local laptop_conf="$HOME/.config/hypr/laptop.conf"

    # Check if system has backlight support (laptop)
    if [ -d /sys/class/backlight ] && [ -n "$(ls -A /sys/class/backlight 2>/dev/null)" ]; then
        log_info "Laptop detected - brightness controls enabled"
    else
        log_info "Desktop detected - disabling brightness controls"
        [ -f "$laptop_conf" ] && > "$laptop_conf"
    fi
}

# Apply system configurations
system_apply() {
    # Validate and cache sudo access at the beginning
    if ! sudo -v; then
        log_error "Failed to authenticate with sudo"
        return 1
    fi

    # Initialize logging for system operations
    init_logging "daily"

    # Start live log monitor (same polished UX as full install)
    start_log_monitor

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
        stop_log_monitor
    }
    trap cleanup_sudo EXIT INT TERM

    # Run individual system configuration scripts with logging
    run_logged "$DOTFILES_DIR/install/system/systemd-sleep.sh"
    run_logged "$DOTFILES_DIR/install/system/logind.sh"
    run_logged "$DOTFILES_DIR/install/system/makepkg.sh"
    run_logged "$DOTFILES_DIR/install/system/timezone.sh"
    run_logged "$DOTFILES_DIR/install/system/systemd-resolved.sh"
    run_logged "$DOTFILES_DIR/install/system/bluetooth.sh"
    run_logged "$DOTFILES_DIR/install/system/esp32.sh"
    run_logged "$DOTFILES_DIR/install/system/app-launcher.sh"
    run_logged "$DOTFILES_DIR/install/system/greeter.sh"

    # Configure laptop-specific settings
    configure_laptop_settings

    # Cleanup
    cleanup_sudo

    # Check if reboot is needed and prompt (only if not in full install)
    if [[ -f "$HOME/.local/state/dotfiles/.reboot_needed" && -z "${FULL_INSTALL:-}" ]]; then
        echo
        log_warning "Reboot required to apply changes"
        if confirm "Reboot now?"; then
            rm -f "$HOME/.local/state/dotfiles/.reboot_needed"
            sudo systemctl reboot
        fi
    fi

    echo
    log_success "System configuration complete"
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

# System management menu
system_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"

    while true; do
        clear_screen "System"

        local action=$(choose_option \
            "Apply configurations" \
            "Back")

        [[ -z "$action" ]] && return

        case "$action" in
            "Apply configurations")
                run_operation "" system_apply
                ;;
            "Back")
                return
                ;;
        esac
    done
}
