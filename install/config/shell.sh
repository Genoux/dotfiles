#!/bin/bash
# Setup shell (zsh, oh-my-zsh, plugins)

# Source helpers first
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Source shell library
source "$DOTFILES_DIR/lib/shell.sh"

log_info "Setting up shell..."

# Run shell setup
shell_setup

