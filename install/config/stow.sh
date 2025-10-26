#!/bin/bash
# Stow all configs

# Source helpers first
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Source config library
source "$DOTFILES_DIR/lib/config.sh"

log_info "Linking all configurations..."

# Link all configs
config_link_all true

echo
log_info "Installing dotfiles command..."

# Ensure ~/.local/bin exists
ensure_directory "$HOME/.local/bin"

# Create symlink to dotfiles command
if [[ -L "$HOME/.local/bin/dotfiles" ]]; then
    log_info "dotfiles command already linked"
elif [[ -e "$HOME/.local/bin/dotfiles" ]]; then
    log_warning "File exists at ~/.local/bin/dotfiles (not a symlink)"
else
    ln -s "$DOTFILES_DIR/dotfiles" "$HOME/.local/bin/dotfiles"
    log_success "dotfiles command installed"
fi

echo
log_info "Enabling systemd user services..."

# Reload user systemd daemon to pick up new services
systemctl --user daemon-reload

# Enable and restart AGS service to pick up new configurations
if [[ -f "$HOME/.config/systemd/user/ags.service" ]]; then
    systemctl --user enable ags.service
    
    # Restart the service to pick up new configurations
    if systemctl --user is-active --quiet ags.service; then
        log_info "AGS service is running, restarting to pick up new configurations..."
        systemctl --user restart ags.service
        log_success "AGS service restarted"
    else
        log_info "AGS service not running, starting..."
        systemctl --user start ags.service
        log_success "AGS service started"
    fi
else
    log_warning "AGS service file not found, skipping"
fi

