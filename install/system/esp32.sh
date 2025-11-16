#!/bin/bash
# ESP32 USB-to-Serial driver configuration
# Installs system-level configs for ESP32 development

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
else
    # Ensure helpers are sourced even if flag is set (might be from different shell)
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "ESP32"

# ESP32 USB-to-Serial driver configuration
if [[ -d "$SYSTEM_DIR/modules-load.d" ]]; then
    sudo mkdir -p /etc/modules-load.d
    for file in "$SYSTEM_DIR/modules-load.d"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            sudo cp "$file" /etc/modules-load.d/
            log_success "$filename"
        fi
    done
fi

# ESP32 udev rules
if [[ -d "$SYSTEM_DIR/udev/rules.d" ]]; then
    sudo mkdir -p /etc/udev/rules.d
    for file in "$SYSTEM_DIR/udev/rules.d"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            sudo cp "$file" /etc/udev/rules.d/
            log_success "$filename"
        fi
    done
    # Reload udev rules
    if command -v udevadm &>/dev/null; then
        sudo udevadm control --reload-rules >/dev/null 2>&1
        sudo udevadm trigger >/dev/null 2>&1
    fi
fi

# Add user to uucp group for ESP32 serial port access
if ! groups "$USER" | grep -q "\buucp\b"; then
    sudo usermod -a -G uucp "$USER"
    log_success "Added to uucp group"
fi

