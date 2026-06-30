#!/bin/bash
# Install PAM configs for user-space session locks

DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
fi

log_info "Installing PAM configurations..."

sudo install -m 644 "$DOTFILES_DIR/system/pam.d/quickshell-lock" /etc/pam.d/quickshell-lock

log_success "PAM configurations installed"
