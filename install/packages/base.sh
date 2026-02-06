#!/bin/bash
# Install base packages from packages/arch.package

# Source helpers first
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Source package library
source "$DOTFILES_DIR/lib/package.sh"

# Setup hardware-specific packages FIRST (GPU drivers, CPU microcode)
# This detects hardware and generates package lists before installation
hardware_packages_setup

# Install packages (now includes hardware packages)
packages_install
