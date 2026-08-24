#!/bin/bash
# Sunshine remote-desktop host: input group for Moonlight keyboard/mouse

DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
else
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "Sunshine"

if ! groups "$USER" | grep -q "\binput\b"; then
    sudo usermod -a -G input "$USER"
    log_success "Added to input group (log out once for it to apply)"
else
    log_info "Already in input group"
fi
