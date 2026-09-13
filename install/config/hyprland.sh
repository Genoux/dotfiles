#!/bin/bash
# Setup Hyprland configuration

# Get dotfiles directory if not set
if [[ -z "${DOTFILES_DIR:-}" ]]; then
    # From install/config/hyprland.sh, go up two levels to root
    export DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
fi

if [[ -z "${DOTFILES_INSTALL:-}" ]]; then
    export DOTFILES_INSTALL="$DOTFILES_DIR/install"
fi

# Source helpers first
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
fi

# Source hyprland libraries
source "$DOTFILES_DIR/lib/hyprland.sh"
source "$DOTFILES_DIR/lib/hyprland-plugins.sh"

# Only setup if Hyprland is installed
if ! command -v hyprctl &>/dev/null; then
    log_info "Hyprland not installed, skipping Hyprland setup"
    exit 0
fi

log_section "Hyprland Configuration"

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    instances=$(hyprctl instances -j 2>/dev/null || true)
    instance=$(jq -r 'if length == 1 then .[0].instance else empty end' <<< "${instances:-[]}" 2>/dev/null || true)
    if [[ -n "$instance" ]]; then
        export HYPRLAND_INSTANCE_SIGNATURE="$instance"
    fi
fi

hyprland_setup_gpu || exit 1
hyprland_setup || exit 1

pending="$HOME/.local/state/dotfiles/hyprland-setup-pending"
if ! hyprctl version &>/dev/null; then
    mkdir -p "$(dirname "$pending")"
    touch "$pending"
    log_info "Plugin setup will run automatically at the first Hyprland login."
elif command -v hyprpm &>/dev/null; then
    setup_hyprland_plugins || exit 1
    rm -f "$pending"
else
    log_error "hyprpm is missing. Run dotfiles packages install."
    exit 1
fi
