#!/bin/bash
# ZRAM Setup Script
# Installs and configures ZRAM compressed swap for better performance

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
else
    # Ensure helpers are sourced even if flag is set (might be from different shell)
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "ZRAM Compressed Swap"

# zram-generator is tracked in packages/arch.package, installed by the
# official phase's single `pacman -Syu` — verify only, no second install path.
if ! pacman -Qi zram-generator &>/dev/null; then
    log_error "zram-generator not installed. Run: dotfiles packages install"
    exit 1
fi

# Copy ZRAM configuration
zram_config_changed=false
if [[ -f "$SYSTEM_DIR/systemd/zram-generator.conf" ]]; then
    if install_file_if_changed "$SYSTEM_DIR/systemd/zram-generator.conf" /etc/systemd/zram-generator.conf; then
        zram_config_changed=true
        log_success "zram-generator.conf"
    else
        log_info "zram-generator.conf already up to date"
    fi
fi

sudo systemctl daemon-reload
sudo systemctl enable systemd-zram-setup@zram0.service 2>/dev/null || true

if swapon --show | grep -q zram; then
    if $zram_config_changed; then
        # zram-generator only reads its config when the device is (re)created;
        # resizing a live swap device in place isn't supported, and restarting
        # it while something is actively swapped out risks that data. Defer
        # to the next reboot rather than restarting it here.
        log_warning "ZRAM config changed — new sizing takes effect after reboot"
        mkdir -p "$HOME/.local/state/dotfiles"
        touch "$HOME/.local/state/dotfiles/.reboot_needed"
    else
        log_success "ZRAM active ($(swapon --show | grep zram | awk '{print $3}'))"
    fi
else
    sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
    if swapon --show | grep -q zram; then
        log_success "ZRAM active ($(swapon --show | grep zram | awk '{print $3}'))"
    else
        log_warning "ZRAM will be active after reboot"
        mkdir -p "$HOME/.local/state/dotfiles"
        touch "$HOME/.local/state/dotfiles/.reboot_needed"
    fi
fi
