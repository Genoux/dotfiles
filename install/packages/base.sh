#!/bin/bash
# Install base packages from packages/arch.package

# Source helpers first
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
fi

# Source package library
source "$DOTFILES_DIR/lib/package.sh"

# Hardware packages should already be detected in hardware_detect phase
# Just verify and install if needed
if [[ ! -d "$DOTFILES_DIR/packages/hardware" ]] || [[ -z "$(ls -A "$DOTFILES_DIR/packages/hardware" 2>/dev/null)" ]]; then
    log_warning "Hardware packages not detected, running detection now..."
    hardware_packages_setup
fi

# Install packages (now includes hardware packages)
packages_install
