#!/bin/bash
# Install base packages from packages.txt

log_info "Installing official packages..."

# Source package library
source "$DOTFILES_DIR/lib/package.sh"

# Install packages
packages_install

