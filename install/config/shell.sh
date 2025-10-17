#!/bin/bash
# Setup shell (zsh, oh-my-zsh, plugins)

log_info "Setting up shell..."

# Source shell library
source "$DOTFILES_DIR/lib/shell.sh"

# Run shell setup
shell_setup

