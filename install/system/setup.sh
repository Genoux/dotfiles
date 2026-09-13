#!/bin/bash
# System configuration installer
# Installs system-level configs that require root access

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
fi

log_info "Installing system-level configurations..."

# Validate and cache sudo access at the beginning
if ! ensure_sudo; then
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
    terminate_process_tree "$SUDO_KEEPALIVE_PID"
    wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup_sudo EXIT

# Run individual system configuration scripts
run_logged "$DOTFILES_DIR/install/system/hardware-drivers.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/systemd-sleep.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/logind.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/journald.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/timezone.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/network.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/bluetooth.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/esp32.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/sunshine.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/keyd.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/tlp.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/zram.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/cpufreq.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/plymouth.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/greeter.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/pam.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/pacman-hooks.sh" || exit 1
run_logged "$DOTFILES_DIR/install/system/root-space.sh" || exit 1

log_success "System configuration complete"
