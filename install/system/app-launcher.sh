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

log_section "App Launcher Setup"

# Check if elephant is installed
if ! command -v elephant &>/dev/null; then
    log_warning "Elephant not found - install packages first"
    log_info "Run: dotfiles packages install"
    exit 0
fi

# Enable and start elephant service
log_info "Configuring elephant service..."

# Reload systemd to pick up any new service files
systemctl --user daemon-reload

# Check if service file exists
if [[ -f "$HOME/.config/systemd/user/elephant.service" ]]; then
    # Enable service
    systemctl --user enable elephant.service

    # Restart service
    if systemctl --user is-active --quiet elephant.service; then
        log_info "Restarting elephant service..."
        systemctl --user restart elephant.service
    else
        log_info "Starting elephant service..."
        systemctl --user start elephant.service
    fi

    # Check if service started successfully
    sleep 1
    if systemctl --user is-active --quiet elephant.service; then
        log_success "Elephant service is running"
    else
        log_error "Elephant service failed to start"
        log_info "Check logs with: journalctl --user -u elephant.service"
        exit 1
    fi
else
    log_warning "Elephant service file not found at ~/.config/systemd/user/elephant.service"
    log_info "You may need to run: dotfiles config link"
fi

echo

# Verify elephant is working
log_info "Verifying elephant providers..."
sleep 1

# Check for plugin loading errors
if journalctl --user -u elephant.service -n 20 --no-pager | grep -q "ERROR.*plugin"; then
    log_error "Elephant has plugin loading errors"
    log_info "Check logs with: journalctl --user -u elephant.service"
    exit 1
else
    log_success "All elephant providers loaded successfully"
fi

echo

# Check Walker configuration
if command -v walker &>/dev/null; then
    log_info "Walker is installed"

    if [[ -f "$HOME/.config/walker/config.toml" ]]; then
        if grep -q 'name = "elephant"' "$HOME/.config/walker/config.toml"; then
            log_success "Walker is configured to use elephant"
        else
            log_warning "Walker config doesn't reference elephant plugin"
        fi
    else
        log_warning "Walker config not found - you may need to run: dotfiles config link"
    fi
else
    log_warning "Walker not installed"
    log_info "Install it from AUR: yay -S walker-bin"
fi

echo
log_success "App launcher setup complete"
echo
log_info "Test Walker by pressing your configured keybind (usually Super+Space)"
log_info "You should see desktop applications when you search"
