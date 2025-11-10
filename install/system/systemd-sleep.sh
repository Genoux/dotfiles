#!/bin/bash
# systemd sleep configuration
# Installs systemd sleep hooks and configuration

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
else
    # Ensure helpers are sourced even if flag is set (might be from different shell)
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "systemd Sleep Configuration"

# systemd sleep configuration
if [[ -d "$SYSTEM_DIR/systemd/sleep.conf.d" ]]; then
    log_info "Installing systemd sleep configuration..."
    sudo mkdir -p /etc/systemd/sleep.conf.d
    for file in "$SYSTEM_DIR/systemd/sleep.conf.d"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            sudo cp "$file" /etc/systemd/sleep.conf.d/
            log_success "Installed $filename"
        fi
    done
fi

log_success "systemd sleep configuration complete"

