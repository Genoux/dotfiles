#!/bin/bash
# Enable and restart systemd user services

# Get script directory and dotfiles root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source helpers directly
source "$DOTFILES_DIR/install/helpers/all.sh"

echo
log_section "Managing Systemd Services"

# Reload user systemd daemon to pick up new services
systemctl --user daemon-reload

# Collect all services
services=()
for service_file in "$HOME/.config/systemd/user"/*.service; do
    if [[ -f "$service_file" ]]; then
        services+=("$(basename "$service_file")")
    fi
done

# Process services with spinner
if [[ ${#services[@]} -gt 0 ]]; then
    gum spin --spinner dot --title "Restarting services..." -- bash -c '
        for service in "$@"; do
            systemctl --user enable "$service" 2>/dev/null
            
            if systemctl --user is-active --quiet "$service"; then
                systemctl --user restart "$service" 2>/dev/null
            else
                systemctl --user start "$service" 2>/dev/null
            fi
        done
    ' _ "${services[@]}"
    
    log_success "All services enabled and started"
    
else
    log_info "No services found"
fi

echo
