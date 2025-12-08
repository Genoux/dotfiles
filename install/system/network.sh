#!/bin/bash
# Network configuration setup
# Configures Wake-on-LAN and other network settings

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
else
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "Network Configuration"

# Detect primary ethernet interface (exclude virtual interfaces like docker, veth, br-)
ETHERNET_INTERFACE=$(ip -o link show | grep -v "lo:" | grep -vE "docker|veth|br-|virbr" | grep -E "enp|eth|eno" | head -1 | awk '{print $2}' | tr -d ':')

if [[ -z "$ETHERNET_INTERFACE" ]]; then
    log_warning "No ethernet interface found, skipping WoL configuration"
    exit 0
fi

log_info "Detected ethernet interface: $ETHERNET_INTERFACE"

# Check if interface supports WoL
if ! command -v ethtool &>/dev/null; then
    log_warning "ethtool not installed, skipping WoL configuration"
    exit 0
fi

WOL_SUPPORT=$(sudo ethtool "$ETHERNET_INTERFACE" 2>/dev/null | grep "Supports Wake-on" | awk '{print $3}')
if [[ -z "$WOL_SUPPORT" || "$WOL_SUPPORT" == "d" ]]; then
    log_warning "Interface $ETHERNET_INTERFACE doesn't support Wake-on-LAN"
    exit 0
fi

log_info "WoL supported modes: $WOL_SUPPORT"

# Install NetworkManager dispatcher script for WoL
log_info "Installing NetworkManager WoL dispatcher script..."

sudo mkdir -p /etc/NetworkManager/dispatcher.d

sudo tee /etc/NetworkManager/dispatcher.d/99-wol >/dev/null <<EOF
#!/bin/bash
# Enable Wake-on-LAN when interface comes up

INTERFACE=\$1
ACTION=\$2

if [[ "\$INTERFACE" == "$ETHERNET_INTERFACE" ]] && [[ "\$ACTION" == "up" ]]; then
    /usr/bin/ethtool -s "\$INTERFACE" wol g
    logger "Wake-on-LAN enabled for \$INTERFACE"
fi
EOF

sudo chmod +x /etc/NetworkManager/dispatcher.d/99-wol
log_success "NetworkManager dispatcher script installed"

# Enable WoL immediately for current session
log_info "Enabling WoL for current session..."
if sudo ethtool -s "$ETHERNET_INTERFACE" wol g 2>/dev/null; then
    log_success "WoL enabled for $ETHERNET_INTERFACE"
else
    log_warning "Failed to enable WoL immediately (will be enabled on next network restart)"
fi

# Verify WoL status
CURRENT_WOL=$(sudo ethtool "$ETHERNET_INTERFACE" 2>/dev/null | grep "Wake-on:" | awk '{print $2}')
if [[ "$CURRENT_WOL" == "g" ]]; then
    log_success "WoL is active (mode: g - magic packet)"
else
    log_info "Current WoL mode: $CURRENT_WOL"
fi

log_success "Network configuration complete"
