#!/bin/bash
# App Launcher (Walker + Elephant) Setup
# Handles installation, rebuilding, and service management for the app launcher stack

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
else
    # Ensure helpers are sourced even if flag is set (might be from different shell)
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "App Launcher"

# Check if elephant is installed
if ! command -v elephant &>/dev/null; then
    exit 0
fi

# Enable and start elephant service
systemctl --user daemon-reload 2>/dev/null

# Check if service file exists
if [[ -f "$HOME/.config/systemd/user/elephant.service" ]]; then
    systemctl --user enable elephant.service 2>/dev/null
    systemctl --user restart elephant.service 2>/dev/null

    sleep 1
    if systemctl --user is-active --quiet elephant.service; then
        log_success "Elephant service started"
    fi

    # Check for plugin loading errors
    if ! journalctl --user -u elephant.service -n 20 --no-pager 2>/dev/null | grep -q "ERROR.*plugin"; then
        log_success "Providers loaded"
    fi
fi
