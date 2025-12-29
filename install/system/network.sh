#!/bin/bash
# Network configuration setup
# Configures iwd + systemd-networkd with WiFi and Ethernet support
# Wake-on-LAN configuration for ethernet interfaces

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
else
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "Network Configuration (iwd + systemd-networkd)"

# Step 1: Disable conflicting services
log_info "Disabling conflicting network services..."

if systemctl is-enabled NetworkManager &>/dev/null; then
    log_info "Disabling NetworkManager..."
    sudo systemctl stop NetworkManager 2>/dev/null || true
    sudo systemctl disable NetworkManager 2>/dev/null || true
fi

if systemctl is-enabled wpa_supplicant &>/dev/null || systemctl is-active wpa_supplicant &>/dev/null; then
    log_info "Disabling wpa_supplicant..."
    sudo systemctl stop wpa_supplicant 2>/dev/null || true
    sudo systemctl disable wpa_supplicant 2>/dev/null || true
    sudo systemctl mask wpa_supplicant 2>/dev/null || true
fi

log_success "Conflicting services disabled"

# Step 2: Configure iwd for WiFi
log_info "Configuring iwd for WiFi management..."

sudo mkdir -p /etc/iwd

sudo tee /etc/iwd/main.conf >/dev/null <<'EOF'
[General]
EnableNetworkConfiguration=true
UseDefaultInterface=true

[Network]
NameResolvingService=systemd
EOF

sudo systemctl enable iwd
sudo systemctl restart iwd
log_success "iwd configured and enabled"

# Step 3: Configure systemd-networkd and systemd-resolved
log_info "Configuring systemd-networkd..."

sudo mkdir -p /etc/systemd/network

# Ethernet configuration with DHCP
sudo tee /etc/systemd/network/20-wired.network >/dev/null <<'EOF'
[Match]
Name=en*
Name=eth*

[Network]
DHCP=yes
DNS=1.1.1.1
DNS=8.8.8.8

[DHCP]
RouteMetric=100
EOF

# WiFi configuration (managed by iwd)
sudo tee /etc/systemd/network/25-wireless.network >/dev/null <<'EOF'
[Match]
Name=wlan*

[Network]
DHCP=yes
DNS=1.1.1.1
DNS=8.8.8.8

[DHCP]
RouteMetric=200
EOF

sudo systemctl enable systemd-networkd
sudo systemctl enable systemd-resolved
sudo systemctl restart systemd-networkd
sudo systemctl restart systemd-resolved

# Configure DNS resolution
if [[ ! -L /etc/resolv.conf ]] || [[ "$(readlink /etc/resolv.conf)" != "/run/systemd/resolve/stub-resolv.conf" ]]; then
    log_info "Configuring DNS resolution..."
    sudo rm -f /etc/resolv.conf
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
fi

log_success "systemd-networkd and systemd-resolved configured"

# Step 4: Configure Wake-on-LAN for Ethernet
log_info "Configuring Wake-on-LAN..."

# Detect primary ethernet interface (exclude virtual interfaces)
ETHERNET_INTERFACE=$(ip -o link show | grep -v "lo:" | grep -vE "docker|veth|br-|virbr|wlan" | grep -E "enp|eth|eno" | head -1 | awk '{print $2}' | tr -d ':')

if [[ -z "$ETHERNET_INTERFACE" ]]; then
    log_warning "No ethernet interface found, skipping WoL configuration"
else
    log_info "Detected ethernet interface: $ETHERNET_INTERFACE"

    # Check if ethtool is available
    if ! command -v ethtool &>/dev/null; then
        log_warning "ethtool not installed, skipping WoL configuration"
    else
        # Check WoL support
        WOL_SUPPORT=$(sudo ethtool "$ETHERNET_INTERFACE" 2>/dev/null | grep "Supports Wake-on" | awk '{print $3}')

        if [[ -n "$WOL_SUPPORT" && "$WOL_SUPPORT" != "d" ]]; then
            log_info "WoL supported modes: $WOL_SUPPORT"

            # Get MAC address for the interface
            MAC_ADDRESS=$(ip link show "$ETHERNET_INTERFACE" | grep link/ether | awk '{print $2}')

            if [[ -n "$MAC_ADDRESS" ]]; then
                # Create systemd-networkd link file for WoL
                sudo tee /etc/systemd/network/10-${ETHERNET_INTERFACE}.link >/dev/null <<EOF
[Match]
MACAddress=$MAC_ADDRESS

[Link]
WakeOnLan=magic
EOF

                log_success "WoL link file created for $ETHERNET_INTERFACE"

                # Enable WoL immediately for current session
                if sudo ethtool -s "$ETHERNET_INTERFACE" wol g 2>/dev/null; then
                    CURRENT_WOL=$(sudo ethtool "$ETHERNET_INTERFACE" 2>/dev/null | grep "Wake-on:" | awk '{print $2}')
                    if [[ "$CURRENT_WOL" == "g" ]]; then
                        log_success "WoL enabled for $ETHERNET_INTERFACE (mode: magic packet)"
                    else
                        log_info "Current WoL mode: $CURRENT_WOL"
                    fi
                else
                    log_warning "Failed to enable WoL immediately (will be enabled on next boot)"
                fi
            else
                log_warning "Could not detect MAC address for $ETHERNET_INTERFACE"
            fi
        else
            log_warning "Interface $ETHERNET_INTERFACE doesn't support Wake-on-LAN"
        fi
    fi
fi

# Clean up old NetworkManager dispatcher scripts if they exist
if [[ -f /etc/NetworkManager/dispatcher.d/99-wol ]]; then
    log_info "Removing old NetworkManager WoL dispatcher script..."
    sudo rm -f /etc/NetworkManager/dispatcher.d/99-wol
fi

log_success "Network configuration complete"
log_info "Architecture: iwd (WiFi) + systemd-networkd (Ethernet) + systemd-resolved (DNS)"
log_info "Use 'impala' TUI to manage WiFi connections"
