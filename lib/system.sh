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
    # Confirm before making system-wide changes
    if [[ "${AUTO_YES:-false}" != "true" ]]; then
        echo
        gum style --bold --foreground "$CONFIRM_TITLE_COLOR" "⚠ System Configuration"
        echo
        echo "This will modify system-level settings:"
        echo "  • TLP power management"
        echo "  • systemd sleep/logind"
        echo "  • Network/Bluetooth configuration"
        echo "  • Plymouth boot screen"
        echo
        if ! gum_confirm "Apply system configuration?"; then
            return 0
        fi
        echo
    fi

    # Initialize logging and start progress display
    init_logging "daily"
    progress_start "System Configuration"

    # Cleanup function
    trap 'progress_cleanup; finish_logging' EXIT INT TERM

    # Run individual system configuration scripts with logging
    progress_run_script "$DOTFILES_DIR/install/system/sudoers.sh"
    progress_run_script "$DOTFILES_DIR/install/system/tlp.sh"
    progress_run_script "$DOTFILES_DIR/install/system/systemd-sleep.sh"
    progress_run_script "$DOTFILES_DIR/install/system/logind.sh"
    progress_run_script "$DOTFILES_DIR/install/system/makepkg.sh"
    progress_run_script "$DOTFILES_DIR/install/system/timezone.sh"
    progress_run_script "$DOTFILES_DIR/install/system/systemd-resolved.sh"
    progress_run_script "$DOTFILES_DIR/install/system/bluetooth.sh"
    progress_run_script "$DOTFILES_DIR/install/system/esp32.sh"
    progress_run_script "$DOTFILES_DIR/install/system/app-launcher.sh"
    progress_run_script "$DOTFILES_DIR/install/system/greeter.sh"
    progress_run_script "$DOTFILES_DIR/install/system/plymouth.sh"

    # Configure laptop-specific settings
    echo
    echo "Configuring laptop-specific settings..."
    configure_laptop_settings

    # Complete
    trap - EXIT INT TERM
    finish_logging

    progress_complete "System Configuration" "system"
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
        clear_screen "System"
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
