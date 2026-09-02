#!/bin/bash
# Enable and restart systemd user services

# Get script directory and dotfiles root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source helpers directly
source "$DOTFILES_DIR/install/helpers/all.sh"

echo
log_section "Managing Systemd Services"

# Reload user systemd daemon to pick up new services and timers
systemctl --user daemon-reload

# Collect all services
# Oneshot units are timer-triggered or manual, and `start` blocks until they finish
services=()
for service_file in "$HOME/.config/systemd/user"/*.service; do
    if [[ -f "$service_file" ]]; then
        service="$(basename "$service_file")"
        if [[ "$(systemctl --user show -p Type --value "$service")" != "oneshot" ]]; then
            services+=("$service")
        fi
    fi
done

# Collect all timers
timers=()
for timer_file in "$HOME/.config/systemd/user"/*.timer; do
    if [[ -f "$timer_file" ]]; then
        timers+=("$(basename "$timer_file")")
    fi
done

# Process services with spinner
if [[ ${#services[@]} -gt 0 ]]; then
    gum spin --spinner dot --title "Starting services..." -- bash -c '
        for service in "$@"; do
            systemctl --user enable "$service" 2>/dev/null

            if ! systemctl --user is-active --quiet "$service"; then
                systemctl --user start "$service" 2>/dev/null
                continue
            fi

            # Restarting a healthy daemon drops live state it cannot recover
            # (awww loses the wallpaper on an empty cache), so only restart when
            # the unit file actually changed after the service came up
            unit=$(systemctl --user show -p FragmentPath --value "$service")
            started=$(systemctl --user show -p ActiveEnterTimestamp --value "$service")
            unit_mtime=$(stat -Lc %Y "$unit" 2>/dev/null || echo 0)
            started_epoch=$(date -d "$started" +%s 2>/dev/null || echo 0)

            if (( started_epoch > 0 && unit_mtime > started_epoch )); then
                systemctl --user restart "$service" 2>/dev/null
            fi
        done
    ' _ "${services[@]}"
    
    log_success "All services enabled and started"
else
    log_info "No services found"
fi

# Process timers with spinner
if [[ ${#timers[@]} -gt 0 ]]; then
    echo
    gum spin --spinner dot --title "Enabling timers..." -- bash -c '
        for timer in "$@"; do
            systemctl --user enable "$timer" 2>/dev/null
            systemctl --user start "$timer" 2>/dev/null
        done
    ' _ "${timers[@]}"
    
    log_success "All timers enabled and started"
else
    log_info "No timers found"
fi

echo
