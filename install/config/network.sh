#!/bin/bash
# Network configuration setup (one-time system configuration)

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

setup_network() {
    log_section "Network Configuration"
    
    # Check if NetworkManager is installed
    if ! command -v nmcli &>/dev/null; then
        log_info "NetworkManager not installed, skipping network configuration"
        return 0
    fi
    
    # NetworkManager boot fix - wait for network subsystem
    log_info "Installing NetworkManager boot fix..."
    
    if ! sudo mkdir -p /etc/systemd/system/NetworkManager.service.d; then
        graceful_error "Failed to create systemd NetworkManager directory"
        return 1
    fi
    
    sudo tee /etc/systemd/system/NetworkManager.service.d/wait-for-network-device.conf >/dev/null <<'EOF'
[Unit]
# Wait for network subsystem to be ready before starting NetworkManager
After=network-pre.target
Wants=network-pre.target
EOF
    
    if [[ $? -eq 0 ]]; then
        log_success "NetworkManager boot fix installed"
    else
        graceful_error "Failed to install NetworkManager boot fix"
        return 1
    fi
    
    # NetworkManager dispatcher script - wait for online
    log_info "Installing NetworkManager dispatcher script..."
    
    if ! sudo mkdir -p /etc/NetworkManager/dispatcher.d; then
        graceful_error "Failed to create NetworkManager dispatcher directory"
        return 1
    fi
    
    # Remove existing file/symlink if present
    sudo rm -f /etc/NetworkManager/dispatcher.d/02-wait-online
    
    if ! sudo tee /etc/NetworkManager/dispatcher.d/02-wait-online >/dev/null <<'EOF'
#!/bin/bash
# Wait for network to be truly online before continuing

INTERFACE=$1
ACTION=$2

if [ "$ACTION" = "up" ]; then
    # Wait for actual internet connectivity
    for i in {1..10}; do
        if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            logger "Network online on $INTERFACE"
            exit 0
        fi
        sleep 1
    done
    logger "Network timeout on $INTERFACE"
fi
EOF
    then
        graceful_error "Failed to create dispatcher script file"
        return 1
    fi
    
    if ! sudo chmod +x /etc/NetworkManager/dispatcher.d/02-wait-online; then
        graceful_error "Failed to make dispatcher script executable"
        return 1
    fi
    
    log_success "NetworkManager dispatcher script installed"

    # NetworkManager resume hook - restart NetworkManager after sleep/suspend
    log_info "Installing NetworkManager resume hook..."

    sudo tee /etc/systemd/system/network-resume-hook.service >/dev/null <<'EOF'
[Unit]
Description=Network Resume Hook - Restart NetworkManager after sleep
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl restart NetworkManager.service

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

    if [[ $? -eq 0 ]]; then
        log_success "NetworkManager resume hook installed"
    else
        graceful_error "Failed to install NetworkManager resume hook"
        return 1
    fi

    # Enable the resume hook
    if sudo systemctl enable network-resume-hook.service >/dev/null 2>&1; then
        log_success "NetworkManager resume hook enabled"
    else
        graceful_error "Failed to enable NetworkManager resume hook"
        return 1
    fi

    # Reload systemd
    log_info "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    log_success "Network configuration complete"
    log_info "Boot fix will take effect on next boot"
    log_info "Resume hook will take effect on next suspend/resume"
}

# Run setup when script is executed (not just sourced)
setup_network

