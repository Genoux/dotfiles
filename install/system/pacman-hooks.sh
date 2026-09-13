#!/bin/bash
# Pacman hooks installer

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
fi

log_info "Configuring pacman hooks..."

if ! command -v pacman &>/dev/null; then
    log_warning "pacman is not available. Skipping pacman hooks installation"
    exit 0
fi

# Remove a previous version of this installer's auto-sync mechanism: package
# installs/removals used to get written back into arch.package/aur.package
# automatically, which fought with the hand-curated package lists being the
# single source of truth. Cleans up any machine that ran the old installer.
removed_stale=false
for stale in /etc/pacman.d/hooks/dotfiles-sync-install.hook /etc/pacman.d/hooks/dotfiles-sync-remove.hook; do
    if [[ -f "$stale" ]]; then
        sudo rm -f "$stale"
        removed_stale=true
    fi
done
if [[ -L /usr/local/bin/dotfiles-package-sync || -e /usr/local/bin/dotfiles-package-sync ]]; then
    sudo rm -f /usr/local/bin/dotfiles-package-sync
    removed_stale=true
fi
if $removed_stale; then
    log_success "Removed stale package auto-sync hooks/symlink"
fi

sudo mkdir -p /etc/pacman.d/hooks

CACHE_HOOK="$SYSTEM_DIR/pacman/hooks/dotfiles-clean-cache.hook"
if [[ ! -f "$CACHE_HOOK" ]]; then
    log_error "Hook file not found: $CACHE_HOOK"
    exit 1
fi

if install_file_if_changed "$CACHE_HOOK" /etc/pacman.d/hooks/dotfiles-clean-cache.hook; then
    log_success "Installed dotfiles-clean-cache.hook"
else
    log_info "dotfiles-clean-cache.hook already up to date"
fi
