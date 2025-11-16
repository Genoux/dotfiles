#!/bin/bash
# System configuration installer
# Installs system-level configs that require root access

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

log_info "Installing system-level configurations..."

# Validate and cache sudo access at the beginning
if ! sudo -v; then
    log_error "Failed to authenticate with sudo"
    exit 1
fi

# Keep sudo timestamp fresh in the background
while true; do
    sudo -n true
    sleep 60
    kill -0 $$ 2>/dev/null || exit
done &
SUDO_KEEPALIVE_PID=$!

# Cleanup function
cleanup_sudo() {
    kill $SUDO_KEEPALIVE_PID 2>/dev/null || true
}
trap cleanup_sudo EXIT

# Run individual system configuration scripts
run_logged "$DOTFILES_DIR/install/system/systemd-sleep.sh"
run_logged "$DOTFILES_DIR/install/system/logind.sh"
run_logged "$DOTFILES_DIR/install/system/makepkg.sh"
run_logged "$DOTFILES_DIR/install/system/timezone.sh"
run_logged "$DOTFILES_DIR/install/system/systemd-resolved.sh"
run_logged "$DOTFILES_DIR/install/system/bluetooth.sh"
run_logged "$DOTFILES_DIR/install/system/esp32.sh"

# Cleanup
cleanup_sudo

log_success "System configuration complete"
