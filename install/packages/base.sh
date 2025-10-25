#!/bin/bash
# Install base packages from packages.txt

# Source helpers first
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Source package library
source "$DOTFILES_DIR/lib/package.sh"

# Install packages
packages_install

