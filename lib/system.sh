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
    run_logged "$DOTFILES_DIR/install/system/tlp.sh"
    run_logged "$DOTFILES_DIR/install/system/systemd-sleep.sh"
    run_logged "$DOTFILES_DIR/install/system/logind.sh"
    run_logged "$DOTFILES_DIR/install/system/makepkg.sh"
    run_logged "$DOTFILES_DIR/install/system/timezone.sh"
    run_logged "$DOTFILES_DIR/install/system/systemd-resolved.sh"
    run_logged "$DOTFILES_DIR/install/system/bluetooth.sh"
    run_logged "$DOTFILES_DIR/install/system/esp32.sh"
    run_logged "$DOTFILES_DIR/install/system/app-launcher.sh"
    run_logged "$DOTFILES_DIR/install/system/greeter.sh"
    run_logged "$DOTFILES_DIR/install/system/plymouth.sh"

    # Configure laptop-specific settings
    configure_laptop_settings

    # Cleanup
    cleanup_sudo

    source "$DOTFILES_DIR/lib/menu.sh"
    show_completion_menu "System configuration complete"
}

# Show quick system status summary
system_show_summary() {
    source "$DOTFILES_DIR/lib/menu.sh"

    local applied_count=0
    local total_count=0

    # Count all system config scripts (excluding setup.sh)
    for script in "$DOTFILES_DIR/install/system"/*.sh; do
        [[ ! -f "$script" ]] && continue
        [[ "$(basename "$script")" == "setup.sh" ]] && continue
        ((total_count++))
    done

    # Dynamically check status for each config script
    for script in "$DOTFILES_DIR/install/system"/*.sh; do
        [[ ! -f "$script" ]] && continue
        [[ "$(basename "$script")" == "setup.sh" ]] && continue

        # Check if script has a status check function
        if grep -q "^check_config_status()" "$script" 2>/dev/null; then
            # Source and run the status check
            if (source "$script" 2>/dev/null && check_config_status 2>/dev/null); then
                ((applied_count++))
            fi
        else
            # If no status check defined, assume applied (can't verify)
            ((applied_count++))
        fi
    done

    show_quick_summary "System configs" "$applied_count/$total_count applied"
}

# Show system status
system_status() {
    log_section "Available System Configurations"
    echo

    # List all available config scripts
    for script in "$DOTFILES_DIR/install/system"/*.sh; do
        [[ ! -f "$script" ]] && continue
        [[ "$(basename "$script")" == "setup.sh" ]] && continue

        local script_name=$(basename "$script" .sh)
        local status_icon

        # Check if config has status function and is applied
        if grep -q "^check_config_status()" "$script" 2>/dev/null; then
            if (source "$script" 2>/dev/null && check_config_status 2>/dev/null); then
                status_icon="$(status_ok)"
            else
                status_icon="$(status_warning)"
            fi
        else
            # No status check - assume applied
            status_icon="$(status_ok)"
        fi

        echo "  $status_icon $script_name"
    done

    echo
    log_info "Run 'Apply configurations' to apply all system configs"
}

# System management menu
system_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"

    while true; do
        clear_screen "System Config"
        system_show_summary

        local action=$(choose_option \
            "Apply configurations" \
            "Show details" \
            "Back")

        [[ -z "$action" ]] && return

        case "$action" in
            "Apply configurations")
                system_apply
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
