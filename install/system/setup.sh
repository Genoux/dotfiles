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

# Run individual system configuration scripts
run_logged "$DOTFILES_DIR/install/system/sudoers.sh"
run_logged "$DOTFILES_DIR/install/system/systemd-sleep.sh"
run_logged "$DOTFILES_DIR/install/system/logind.sh"
run_logged "$DOTFILES_DIR/install/system/makepkg.sh"
run_logged "$DOTFILES_DIR/install/system/timezone.sh"
run_logged "$DOTFILES_DIR/install/system/systemd-resolved.sh"
run_logged "$DOTFILES_DIR/install/system/network.sh"
run_logged "$DOTFILES_DIR/install/system/bluetooth.sh"
run_logged "$DOTFILES_DIR/install/system/esp32.sh"
run_logged "$DOTFILES_DIR/install/system/keyd.sh"
run_logged "$DOTFILES_DIR/install/system/tlp.sh"
run_logged "$DOTFILES_DIR/install/system/zram.sh"
run_logged "$DOTFILES_DIR/install/system/cpufreq.sh"
run_logged "$DOTFILES_DIR/install/system/plymouth.sh"

log_success "System configuration complete"
