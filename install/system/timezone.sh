#!/bin/bash
# Timezone configuration
# Automatically sets timezone based on geolocation

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

log_section "Timezone Configuration"

# Automatically set timezone based on geolocation
if command -v tzupdate &>/dev/null; then
    log_info "Detecting and setting timezone automatically..."
    sudo tzupdate -q 2>/dev/null || true
    DETECTED_TZ=$(timedatectl show --value -p Timezone)
    log_success "Timezone set to $DETECTED_TZ"
else
    log_info "tzupdate not installed, skipping automatic timezone detection"
fi

log_success "Timezone configuration complete"

