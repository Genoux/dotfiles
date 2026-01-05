#!/bin/bash
# Setup initial theme

# Source helpers first
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Source theme library
source "$DOTFILES_DIR/lib/theme.sh"

log_info "Setting up themes..."

# Install GTK theme (non-interactive default)
if [[ -x "$DOTFILES_DIR/lib/gtk.sh" ]]; then
    log_info "Installing GTK theme..."
    bash "$DOTFILES_DIR/lib/gtk.sh" install || log_warning "GTK theme installation skipped"
    echo
fi

# Apply flavours color scheme
theme_apply
