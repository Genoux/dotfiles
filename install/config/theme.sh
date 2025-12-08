#!/bin/bash
# Setup initial theme

# Source helpers first
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Source theme library
source "$DOTFILES_DIR/lib/theme.sh"

log_info "Setting up theme..."

# Apply default theme
theme_apply
