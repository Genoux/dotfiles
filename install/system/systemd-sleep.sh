#!/bin/bash
# systemd sleep configuration
# Installs systemd sleep hooks and configuration

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

log_section "systemd Sleep"

# systemd sleep configuration
if [[ -d "$SYSTEM_DIR/systemd/sleep.conf.d" ]]; then
    for file in "$SYSTEM_DIR/systemd/sleep.conf.d"/*; do
        [[ -f "$file" ]] || continue
        filename=$(basename "$file")
        if install_file_if_changed "$file" "/etc/systemd/sleep.conf.d/$filename"; then
            log_success "$filename"
        else
            log_info "$filename already up to date"
        fi
    done
fi

# NVIDIA needs its sleep helpers enabled for reliable Wayland resume.
if systemctl list-unit-files | grep -q "nvidia-suspend.service"; then
    if lspci | grep -i vga | grep -qi nvidia; then
        log_info "NVIDIA GPU detected - enabling NVIDIA suspend services"
        sudo systemctl enable nvidia-suspend.service 2>/dev/null || true
        sudo systemctl enable nvidia-resume.service 2>/dev/null || true
        sudo systemctl enable nvidia-hibernate.service 2>/dev/null || true
        log_success "NVIDIA suspend services enabled"
    else
        log_info "No NVIDIA GPU detected - disabling NVIDIA suspend services"
        sudo systemctl disable nvidia-suspend.service 2>/dev/null || true
        sudo systemctl disable nvidia-resume.service 2>/dev/null || true
        sudo systemctl disable nvidia-hibernate.service 2>/dev/null || true
        log_success "NVIDIA suspend services disabled"
    fi
fi

# Install system-sleep hooks (for hibernate, etc.)
if [[ -d "$SYSTEM_DIR/systemd/system-sleep" ]]; then
    for file in "$SYSTEM_DIR/systemd/system-sleep"/*; do
        [[ -f "$file" ]] || continue
        filename=$(basename "$file")
        if install_file_if_changed "$file" "/usr/lib/systemd/system-sleep/$filename" 755; then
            log_success "Installed system-sleep hook: $filename"
        else
            log_info "system-sleep hook $filename already up to date"
        fi
    done
fi

# Laptop-specific configurations
if is_laptop; then
    log_info "Laptop detected - installing lid switch configuration"

    # Install logind configuration for lid switch behavior
    if [[ -d "$SYSTEM_DIR/systemd/logind.conf.d" ]]; then
        logind_changed=false
        for file in "$SYSTEM_DIR/systemd/logind.conf.d"/*; do
            [[ -f "$file" ]] || continue
            filename=$(basename "$file")
            if install_file_if_changed "$file" "/etc/systemd/logind.conf.d/$filename"; then
                logind_changed=true
                log_success "Installed logind config: $filename"
            else
                log_info "logind config $filename already up to date"
            fi
        done

        if $logind_changed; then
            log_success "Lid switch configuration installed"
            log_warning "Reboot required for logind changes to take effect"
            mkdir -p "$HOME/.local/state/dotfiles"
            touch "$HOME/.local/state/dotfiles/.reboot_needed"
        fi
    fi
else
    log_info "Desktop detected - skipping lid switch configuration"
fi

