#!/bin/bash
# Bluetooth configuration
# Enables Bluetooth auto-start on boot

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
else
    # Ensure helpers are sourced even if flag is set (might be from different shell)
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "Bluetooth"

# Testable without touching the real system file — defaults to the real path.
BLUETOOTH_MAIN_CONF="${BLUETOOTH_MAIN_CONF:-/etc/bluetooth/main.conf}"

# Enable Bluetooth auto-start on boot. bluez ships main.conf as one large
# commented vendor file with no conf.d drop-in support (verified against
# bluez 5.87 — no /etc/bluetooth/main.conf.d), so a single guarded in-place
# edit is used instead of installing a whole replacement file: a full copy
# would freeze out every future bluez default this file doesn't already
# mention. The guard checks the desired end state, not raw text, so
# re-running this is a no-op once AutoEnable=true is set.
#
# A commented-out `#AutoEnable=` line is bluez's own shipped default, but not
# every main.conf has one at all — sed matching nothing is a silent no-op
# that still exits 0, which used to get logged as success. Every branch here
# is verified against the actual file afterward instead of trusted blindly.
configure_bluetooth_autoenable() {
    local conf="$1"

    [[ -f "$conf" ]] || return 0

    if grep -q "^AutoEnable=true" "$conf"; then
        log_info "Auto-enable already configured"
        return 0
    fi

    if grep -q "^#\?AutoEnable=" "$conf"; then
        sudo sed -i 's/^#\?AutoEnable=.*/AutoEnable=true/' "$conf"
    elif grep -q "^\[Policy\]" "$conf"; then
        sudo sed -i '/^\[Policy\]/a AutoEnable=true' "$conf"
    else
        printf '\n[Policy]\nAutoEnable=true\n' | sudo tee -a "$conf" >/dev/null
    fi

    if grep -q "^AutoEnable=true" "$conf"; then
        log_success "Auto-enable configured"
        return 0
    fi

    log_error "Failed to configure AutoEnable in $conf"
    return 1
}

configure_bluetooth_autoenable "$BLUETOOTH_MAIN_CONF"

