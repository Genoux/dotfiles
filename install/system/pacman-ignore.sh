#!/bin/bash
# Keep updates away from hand-built AUR packages
# ghostty-git only builds with --system dropped from its AUR PKGBUILD (see
# packages/aur.package). As a -git package it looks outdated on every upstream
# commit, so without this every update rebuilds it from the stock PKGBUILD and
# fails. Drop it once a stable ghostty release carries the blur fix.

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
fi

PACMAN_CONF="${PACMAN_CONF:-/etc/pacman.conf}"
IGNORED_PACKAGES="ghostty-git ghostty-terminfo-git"
IGNORE_LINE="IgnorePkg = $IGNORED_PACKAGES"

# A line of its own rather than an edit of the vendor IgnorePkg: pacman
# accumulates repeated IgnorePkg lines, so the user's own entries survive.
if grep -qxF "$IGNORE_LINE" "$PACMAN_CONF"; then
    log_info "pacman already ignores $IGNORED_PACKAGES"
elif sudo sed -i "/^\[options\]/a $IGNORE_LINE" "$PACMAN_CONF"; then
    log_success "pacman now ignores $IGNORED_PACKAGES"
else
    log_error "Could not add IgnorePkg to $PACMAN_CONF"
    exit 1
fi
