#!/bin/bash
# Install base packages from packages/arch.package

# Source helpers first
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
fi

# Source package library
source "$DOTFILES_DIR/lib/package.sh"

# Hardware packages/hardware/*.package manifests are static (committed) and
# selected by detection at read time (lib/hardware-packages.sh) — there is
# nothing to (re)generate here; hardware_detect already ran and logged what
# it found.

# Install packages (now includes hardware packages)
packages_install
