#!/bin/bash
# System configuration operations

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Apply system configurations
system_apply() {
    log_section "Applying System Configurations"

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

    echo
    log_success "System configuration complete"
}

# Show system status
system_status() {
    log_section "System Status"

    # makepkg.conf debug status
    if [[ -f /etc/makepkg.conf ]]; then
        if grep -q "OPTIONS=.*!debug.*" /etc/makepkg.conf; then
            show_info "makepkg debug" "disabled ✓"
        else
            show_info "makepkg debug" "enabled (should disable)"
        fi
    else
        show_info "makepkg.conf" "not found"
    fi

    # systemd sleep hooks
    local sleep_hooks=0
    if [[ -d /usr/lib/systemd/system-sleep ]]; then
        sleep_hooks=$(find /usr/lib/systemd/system-sleep -type f 2>/dev/null | wc -l)
    fi
    show_info "systemd sleep hooks" "$sleep_hooks installed"

    # systemd sleep config
    local sleep_configs=0
    if [[ -d /etc/systemd/sleep.conf.d ]]; then
        sleep_configs=$(find /etc/systemd/sleep.conf.d -type f 2>/dev/null | wc -l)
    fi
    show_info "systemd sleep configs" "$sleep_configs installed"
}
