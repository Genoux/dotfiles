#!/bin/bash
# Setup Hyprland configuration

# Get dotfiles directory if not set
if [[ -z "${DOTFILES_DIR:-}" ]]; then
    # From install/config/hyprland.sh, go up two levels to root
    export DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
fi

if [[ -z "${DOTFILES_INSTALL:-}" ]]; then
    export DOTFILES_INSTALL="$DOTFILES_DIR/install"
fi

# Source helpers first
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Source hyprland libraries
source "$DOTFILES_DIR/lib/hyprland.sh"
source "$DOTFILES_DIR/lib/hyprland-plugins.sh"

# Only setup if Hyprland is installed
if ! command -v hyprctl &>/dev/null; then
    log_info "Hyprland not installed, skipping Hyprland setup"
    exit 0
fi

log_section "Hyprland Configuration"

# Setup plugins (doesn't require Hyprland to be running)
if command -v hyprpm &>/dev/null; then
    # Setup plugins - our updated script handles sudo gracefully
    setup_hyprland_plugins
    echo
else
    log_warning "hyprpm not found, skipping plugin setup"
fi

# Only setup monitors if Hyprland is running
if ! hyprctl version &>/dev/null 2>&1; then
    log_warning "Hyprland not running, cannot configure monitors"
    log_info "Plugins configured. Run 'dotfiles hyprland setup' after starting Hyprland to configure monitors"
    exit 0
fi

hyprland_setup

