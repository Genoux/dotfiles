#!/bin/bash
# systemd sleep configuration
# Installs systemd sleep hooks and configuration

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

log_section "systemd Sleep"

# systemd sleep configuration
if [[ -d "$SYSTEM_DIR/systemd/sleep.conf.d" ]]; then
    sudo mkdir -p /etc/systemd/sleep.conf.d
    for file in "$SYSTEM_DIR/systemd/sleep.conf.d"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            sudo cp "$file" /etc/systemd/sleep.conf.d/
            log_success "$filename"
        fi
    done
fi

# Disable NVIDIA suspend services only if using AMD graphics (not NVIDIA)
if systemctl list-unit-files | grep -q "nvidia-suspend.service"; then
    # Check if actually using NVIDIA GPU
    if lspci | grep -i vga | grep -qi nvidia; then
        log_info "NVIDIA GPU detected - keeping NVIDIA suspend services enabled"
    else
        log_info "No NVIDIA GPU detected - disabling NVIDIA suspend services"
        sudo systemctl disable nvidia-suspend.service 2>/dev/null || true
        sudo systemctl disable nvidia-resume.service 2>/dev/null || true
        sudo systemctl disable nvidia-hibernate.service 2>/dev/null || true
        log_success "NVIDIA suspend services disabled"
    fi
fi

