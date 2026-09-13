#!/bin/bash
# ESP32 USB-to-Serial driver configuration
# Installs system-level configs for ESP32 development

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

log_section "ESP32"

# ESP32 USB-to-Serial driver configuration
if [[ -d "$SYSTEM_DIR/modules-load.d" ]]; then
    for file in "$SYSTEM_DIR/modules-load.d"/*; do
        [[ -f "$file" ]] || continue
        filename=$(basename "$file")
        if install_file_if_changed "$file" "/etc/modules-load.d/$filename"; then
            log_success "$filename"
        else
            log_info "$filename already up to date"
        fi
    done
fi

# ESP32 udev rules
if [[ -d "$SYSTEM_DIR/udev/rules.d" ]]; then
    udev_changed=false
    for file in "$SYSTEM_DIR/udev/rules.d"/*; do
        [[ -f "$file" ]] || continue
        filename=$(basename "$file")
        if install_file_if_changed "$file" "/etc/udev/rules.d/$filename"; then
            udev_changed=true
            log_success "$filename"
        else
            log_info "$filename already up to date"
        fi
    done
    # Reload udev rules only when something actually changed
    if $udev_changed && command -v udevadm &>/dev/null; then
        sudo udevadm control --reload-rules >/dev/null 2>&1
        sudo udevadm trigger >/dev/null 2>&1
    fi
fi

# Add user to uucp group for ESP32 serial port access
if ! groups "$USER" | grep -q "\buucp\b"; then
    sudo usermod -a -G uucp "$USER"
    log_success "Added to uucp group"
fi

