#!/bin/bash
# Network configuration setup
# iwd owns WiFi association + addressing, systemd-networkd owns wired
# addressing, systemd-resolved owns DNS. Every service change here is
# enable-only: nothing is restarted or started with --now, so the network
# this same install run still needs (AUR/custom package downloads) keeps
# working off whatever was managing it before. The new configuration takes
# effect at the reboot the installer ends with.

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
else
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "Network Configuration (iwd + systemd-networkd)"

# Step 1: Disable (never stop — that would drop the network this install run
# still needs) conflicting network services for next boot.
log_info "Disabling conflicting network services (takes effect on reboot)..."

if systemctl is-enabled NetworkManager &>/dev/null; then
    sudo systemctl disable NetworkManager
fi

if systemctl is-enabled wpa_supplicant &>/dev/null; then
    sudo systemctl disable wpa_supplicant 2>/dev/null || true
    sudo systemctl mask wpa_supplicant 2>/dev/null || true
fi

log_success "Conflicting services disabled"

# Step 2: iwd owns WiFi association + addressing
log_info "Installing iwd configuration..."
if install_file_if_changed "$DOTFILES_DIR/system/iwd/main.conf" /etc/iwd/main.conf; then
    log_success "iwd configuration installed"
else
    log_info "iwd configuration already up to date"
fi
sudo systemctl enable iwd &>/dev/null

# Step 3: systemd-networkd owns wired addressing only (iwd owns WiFi)
log_info "Installing systemd-networkd configuration..."
if install_file_if_changed "$DOTFILES_DIR/system/systemd/network/20-wired.network" /etc/systemd/network/20-wired.network; then
    log_success "20-wired.network installed"
else
    log_info "20-wired.network already up to date"
fi

# A previous version of this installer also wrote a wireless .network file,
# which raced iwd's own DHCP client for the same interface (two IPs, two
# DHCP leases). iwd alone owns WiFi addressing now.
if [[ -f /etc/systemd/network/25-wireless.network ]]; then
    sudo rm -f /etc/systemd/network/25-wireless.network
    log_success "Removed stale 25-wireless.network (iwd now owns WiFi addressing)"
fi

sudo systemctl enable systemd-networkd &>/dev/null

# Step 4: systemd-resolved owns DNS. FallbackDNS guarantees it always has
# *some* working resolver even when nothing is feeding it real upstream
# servers yet (e.g. still on NetworkManager, or iwd/networkd not applied
# until the next reboot) — verified against ANOTHER machine, this is exactly
# what used to break: resolv.conf got pointed at resolved's stub while
# resolved had zero DNS servers, killing resolution right before AUR builds
# and the custom phase's `git clone`.
log_info "Installing systemd-resolved configuration..."
resolved_changed=false
if install_file_if_changed "$DOTFILES_DIR/system/systemd/resolved.conf.d/dotfiles.conf" /etc/systemd/resolved.conf.d/dotfiles.conf; then
    resolved_changed=true
    log_success "resolved.conf.d/dotfiles.conf installed"
else
    log_info "resolved.conf.d/dotfiles.conf already up to date"
fi

sudo systemctl enable systemd-resolved &>/dev/null

# Starting resolved for the first time is non-disruptive (nothing was
# resolving through it yet). Restarting it after a config change is also
# safe — unlike iwd/networkd, that doesn't drop an established connection.
if systemctl is-active --quiet systemd-resolved; then
    if $resolved_changed; then
        sudo systemctl reload-or-restart systemd-resolved
    fi
else
    sudo systemctl start systemd-resolved
fi

# Only repoint resolv.conf after actually verifying resolution works through
# resolved — never leave the system without working DNS on a guess.
# Parameterized on RESOLV_CONF/STUB_RESOLV for testability without touching
# real system paths; both default to the real ones.
configure_resolv_conf() {
    local resolv_conf="$1"
    local stub_resolv="$2"

    if [[ -L "$resolv_conf" ]] && [[ "$(readlink "$resolv_conf")" == "$stub_resolv" ]]; then
        log_info "resolv.conf already points at systemd-resolved"
        return 0
    fi

    if command -v resolvectl &>/dev/null && timeout 5 resolvectl query archlinux.org &>/dev/null; then
        log_info "Pointing $resolv_conf at systemd-resolved..."
        sudo ln -sf "$stub_resolv" "$resolv_conf"
        log_success "DNS resolution configured"
        return 0
    fi

    log_warning "Could not verify DNS resolution through systemd-resolved — leaving resolv.conf untouched (will be configured on a future run)"
    return 1
}

configure_resolv_conf "${RESOLV_CONF:-/etc/resolv.conf}" "${STUB_RESOLV:-/run/systemd/resolve/stub-resolv.conf}"

log_success "systemd-networkd and systemd-resolved configured"

# Step 5: Wake-on-LAN for the primary ethernet interface. Purely a link
# config + immediate ethtool nudge — doesn't touch WiFi/DHCP/DNS, safe to
# apply live.
log_info "Configuring Wake-on-LAN..."

ETHERNET_INTERFACE=$(ip -o link show | grep -v "lo:" | grep -vE "docker|veth|br-|virbr|wlan" | grep -E "enp|eth|eno" | head -1 | awk '{print $2}' | tr -d ':')

if [[ -z "$ETHERNET_INTERFACE" ]]; then
    log_warning "No ethernet interface found, skipping WoL configuration"
elif ! command -v ethtool &>/dev/null; then
    log_warning "ethtool not installed, skipping WoL configuration"
else
    log_info "Detected ethernet interface: $ETHERNET_INTERFACE"

    WOL_SUPPORT=$(sudo ethtool "$ETHERNET_INTERFACE" 2>/dev/null | grep "Supports Wake-on" | awk '{print $3}')

    if [[ -n "$WOL_SUPPORT" && "$WOL_SUPPORT" != "d" ]]; then
        log_info "WoL supported modes: $WOL_SUPPORT"

        MAC_ADDRESS=$(ip link show "$ETHERNET_INTERFACE" | grep link/ether | awk '{print $2}')

        if [[ -n "$MAC_ADDRESS" ]]; then
            LINK_FILE=$(mktemp)
            cat > "$LINK_FILE" <<EOF
[Match]
MACAddress=$MAC_ADDRESS

[Link]
WakeOnLan=magic
EOF
            if install_file_if_changed "$LINK_FILE" "/etc/systemd/network/10-${ETHERNET_INTERFACE}.link"; then
                log_success "WoL link file created for $ETHERNET_INTERFACE"
            else
                log_info "WoL link file already up to date"
            fi
            rm -f "$LINK_FILE"

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

# Clean up old NetworkManager dispatcher scripts if they exist
if [[ -f /etc/NetworkManager/dispatcher.d/99-wol ]]; then
    log_info "Removing old NetworkManager WoL dispatcher script..."
    sudo rm -f /etc/NetworkManager/dispatcher.d/99-wol
fi

log_success "Network configuration complete"
log_info "Architecture: iwd (WiFi) + systemd-networkd (Ethernet) + systemd-resolved (DNS)"
log_info "Takes full effect after reboot. Use 'impala' TUI to manage WiFi connections"
