#!/bin/bash
# Setup initial theme

log_info "Setting up theme..."

# Source theme library
source "$DOTFILES_DIR/lib/theme.sh"

# Apply default theme
theme_apply
