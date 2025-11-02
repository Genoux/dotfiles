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

# systemd system-sleep hooks
if [[ -d "$SYSTEM_DIR/systemd/system-sleep" ]]; then
    log_info "Installing systemd system-sleep hooks..."
    sudo mkdir -p /usr/lib/systemd/system-sleep
    for file in "$SYSTEM_DIR/systemd/system-sleep"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            sudo cp "$file" /usr/lib/systemd/system-sleep/
            sudo chmod +x "/usr/lib/systemd/system-sleep/$filename"
            log_success "Installed $filename"
        fi
    done
fi

# systemd sleep configuration
if [[ -d "$SYSTEM_DIR/systemd/sleep.conf.d" ]]; then
    log_info "Installing systemd sleep configuration..."
    sudo mkdir -p /etc/systemd/sleep.conf.d
    for file in "$SYSTEM_DIR/systemd/sleep.conf.d"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            sudo cp "$file" /etc/systemd/sleep.conf.d/
            log_success "Installed $filename"
        fi
    done
fi

# makepkg.conf - disable debug packages
if [[ -f /etc/makepkg.conf ]]; then
    log_info "Configuring makepkg.conf (disabling debug packages)..."
    if grep -q "OPTIONS=.*debug.*" /etc/makepkg.conf; then
        sudo sed -i 's/\(OPTIONS=([^)]*\)debug\([^)]*)\)/\1!debug\2/' /etc/makepkg.conf
        log_success "Disabled debug packages in makepkg.conf"
    else
        log_info "makepkg.conf already configured (debug already disabled)"
    fi
fi

# Automatically set timezone based on geolocation
if command -v tzupdate &>/dev/null; then
    log_info "Detecting and setting timezone automatically..."
    if sudo tzupdate -q 2>/dev/null; then
        DETECTED_TZ=$(timedatectl show --value -p Timezone)
        log_success "Timezone automatically set to $DETECTED_TZ"
    else
        log_warning "Failed to auto-detect timezone, keeping current setting"
    fi
else
    log_info "tzupdate not installed, skipping automatic timezone detection"
fi

log_success "System configuration complete"
