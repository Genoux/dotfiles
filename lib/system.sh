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

# Show quick system status summary
system_show_summary() {
    source "$DOTFILES_DIR/lib/menu.sh"

    local applied_count=0
    local total_count=3  # makepkg, sleep, logind

    # Count applied configs (match logic from system_status)
    [[ -f /etc/makepkg.conf ]] && grep -q "OPTIONS=.*!debug.*" /etc/makepkg.conf && ((applied_count++))
    [[ -d /etc/systemd/sleep.conf.d ]] && [[ $(find /etc/systemd/sleep.conf.d -type f 2>/dev/null | wc -l) -gt 0 ]] && ((applied_count++))
    [[ -d /etc/systemd/logind.conf.d ]] && [[ $(find /etc/systemd/logind.conf.d -type f 2>/dev/null | wc -l) -gt 0 ]] && ((applied_count++))

    show_quick_summary "System configs" "$applied_count/$total_count applied"
}

# Show system status
system_status() {
    log_section "System Status"

    local configs_applied=0
    local configs_pending=0

    # Check makepkg.conf debug status
    log_info "Package building:"
    if [[ -f /etc/makepkg.conf ]]; then
        if grep -q "OPTIONS=.*!debug.*" /etc/makepkg.conf; then
            echo "  $(status_ok) makepkg debug disabled"
            ((configs_applied++))
        else
            echo "  $(status_warning) makepkg debug enabled (should disable)"
            ((configs_pending++))
        fi
        echo "  $(gum style --foreground 8 "Config: /etc/makepkg.conf")"
    else
        echo "  $(status_neutral) makepkg.conf not found"
        ((configs_pending++))
    fi

    # Check systemd sleep config
    log_info "Power management:"
    if [[ -d /etc/systemd/sleep.conf.d ]]; then
        local sleep_configs=$(find /etc/systemd/sleep.conf.d -type f 2>/dev/null | wc -l)
        if [[ $sleep_configs -gt 0 ]]; then
            echo "  $(status_ok) systemd sleep configs ($sleep_configs files)"
            ((configs_applied++))
            echo "  $(gum style --foreground 8 "Location: /etc/systemd/sleep.conf.d/")"
        else
            echo "  $(status_warning) systemd sleep configs (directory exists but empty)"
            ((configs_pending++))
        fi
    else
        echo "  $(status_warning) systemd sleep configs (not configured)"
        ((configs_pending++))
    fi


    # Check systemd logind config
    log_info "Login management:"
    if [[ -d /etc/systemd/logind.conf.d ]]; then
        local logind_configs=$(find /etc/systemd/logind.conf.d -type f 2>/dev/null | wc -l)
        if [[ $logind_configs -gt 0 ]]; then
            echo "  $(status_ok) systemd logind configs ($logind_configs files)"
            ((configs_applied++))
            echo "  $(gum style --foreground 8 "Location: /etc/systemd/logind.conf.d/")"
        else
            echo "  $(status_warning) systemd logind configs (directory exists but empty)"
            ((configs_pending++))
        fi
    else
        echo "  $(status_warning) systemd logind configs (not configured)"
        ((configs_pending++))
    fi

    # Check for other system configs
    log_info "Other configurations:"
    local other_configs=(
        "/etc/systemd/resolved.conf.d"
        "/etc/udev/rules.d"
        "/etc/modules-load.d"
    )

    for config_path in "${other_configs[@]}"; do
        local config_name=$(basename "$config_path")
        if [[ -d "$config_path" ]]; then
            local file_count=$(find "$config_path" -type f 2>/dev/null | wc -l)
            if [[ $file_count -gt 0 ]]; then
                echo "  $(status_ok) $config_name ($file_count files)"
                echo "  $(gum style --foreground 8 "Location: $config_path")"
            fi
        fi
    done

    # Show actionable info
    if [[ $configs_pending -gt 0 ]]; then
        log_info "$configs_pending configuration(s) pending"
    fi
}

# System management menu
system_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"

    while true; do
        clear_screen "System"
        system_show_summary

        local action=$(choose_option \
            "Apply configurations" \
            "Show details" \
            "Back")

        [[ -z "$action" ]] && return

        case "$action" in
            "Apply configurations")
                run_operation "" system_apply
                ;;
            "Show details")
                run_operation "" system_status
                ;;
            "Back")
                return
                ;;
        esac
    done
}
