#!/bin/bash
# Stow all configs

log_info "Linking all configurations..."

# Source config library
source "$DOTFILES_DIR/lib/config.sh"

# Link all configs
config_link_all true

