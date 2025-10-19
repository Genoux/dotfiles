#!/bin/bash
# Install base packages from packages.txt

# Source package library
source "$DOTFILES_DIR/lib/package.sh"

log_info "Installing official packages..."

# Install packages
packages_install

