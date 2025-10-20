#!/bin/bash
# AGS configuration setup (one-time system configuration)

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

setup_ags() {
    log_section "AGS Configuration"

    # Check if AGS is installed
    if ! command -v ags &>/dev/null; then
        log_info "AGS not installed, skipping AGS configuration"
        return 0
    fi

    # AGS resume hook - restart AGS after sleep/suspend
    log_info "Installing AGS resume hook..."

    sudo tee /etc/systemd/system/ags-resume-hook.service >/dev/null <<'EOF'
[Unit]
Description=AGS Resume Hook - Restart AGS after sleep
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl --user -M %u@ restart ags.service

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

    if [[ $? -eq 0 ]]; then
        log_success "AGS resume hook installed"
    else
        graceful_error "Failed to install AGS resume hook"
        return 1
    fi

    # Enable the resume hook
    if sudo systemctl enable ags-resume-hook.service >/dev/null 2>&1; then
        log_success "AGS resume hook enabled"
    else
        graceful_error "Failed to enable AGS resume hook"
        return 1
    fi

    # Reload systemd
    log_info "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    log_success "AGS configuration complete"
    log_info "Resume hook will take effect on next suspend/resume"
}

# Run setup when script is executed (not just sourced)
setup_ags
