#!/bin/bash
# makepkg configuration
# Disables debug package generation via a makepkg.conf.d drop-in — never
# edits /etc/makepkg.conf itself (sed-patching it in place is what caused it
# to accumulate "!!!debug" across repeated installer runs).

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
else
    # Ensure helpers are sourced even if flag is set (might be from different shell)
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "makepkg"

if install_file_if_changed "$DOTFILES_DIR/system/makepkg.conf.d/dotfiles.conf" /etc/makepkg.conf.d/dotfiles.conf; then
    log_success "Installed makepkg.conf.d/dotfiles.conf (debug packages disabled)"
else
    log_info "makepkg.conf.d/dotfiles.conf already up to date"
fi
