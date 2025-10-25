#!/bin/bash
# Setup Hyprland monitors

# Source helpers first
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Source hyprland library
source "$DOTFILES_DIR/lib/hyprland.sh"

# Only setup if Hyprland is installed
if ! command -v hyprctl &>/dev/null; then
    log_info "Hyprland not installed, skipping monitor setup"
    exit 0
fi

# Only setup if Hyprland is running
if ! hyprctl version &>/dev/null 2>&1; then
    log_info "Hyprland not running, skipping monitor setup"
    log_info "Run 'dotfiles hyprland setup' after starting Hyprland"
    exit 0
fi

log_info "Setting up Hyprland monitors..."
hyprland_setup true  # Auto-confirm during installation

