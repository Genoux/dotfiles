#!/bin/bash
# Hardware driver post-install setup (DKMS build, module load)
# Must run after the hardware packages (static packages/hardware/*.package
# manifests, selected by detected hardware) are actually installed —
# hardware_detect (install.sh) only detects; installation happens via the
# official phase's single `pacman -Syu`, which runs before this script does
# (config phase runs after packages_official).

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
else
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

source "$DOTFILES_DIR/lib/hardware-packages.sh"

hardware_packages_post_install
