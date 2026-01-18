#!/bin/bash
# System package updates and conflict resolution

# Rebuild yay if it's broken (e.g., after libalpm update)
rebuild_yay_if_broken() {
    if ! command -v yay &>/dev/null; then
        return 0
    fi

    if yay --version &>/dev/null; then
        return 0
    fi

    echo "yay is broken (likely due to library update), rebuilding..."

    if ! (cd /tmp && rm -rf yay && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm); then
        echo "Failed to rebuild yay"
        return 1
    fi

    echo "yay rebuilt successfully"
    return 0
}

# Update system packages
packages_update() {
    # Confirm before running system update
    if [[ "${AUTO_YES:-false}" != "true" ]]; then
        echo
        gum style --bold --foreground "$CONFIRM_TITLE_COLOR" "⚠ System Update"
        echo
        echo "This will update all packages:"
        echo "  • Official Arch packages (pacman -Syu)"
        echo "  • AUR packages (yay -Sua)"
        echo "  • Hyprland plugins (if installed)"
        echo
        if ! gum_confirm "Proceed with system update?"; then
            return 0
        fi
        echo
    fi

    # Initialize logging and start progress display
    init_logging "package"
    progress_start "System Update"

    # Cleanup on exit/interrupt
    trap 'progress_cleanup; finish_logging' EXIT INT TERM

    # Remove debug packages first (silent if none found)
    local debug_packages=$(pacman -Qq | grep '\-debug$' 2>/dev/null || true)
    if [[ -n "$debug_packages" ]]; then
        echo "Removing debug packages..."
        echo "$debug_packages" | xargs sudo pacman -Rdd --noconfirm 2>&1 || true
    fi

    # Sync and update official packages
    echo
    echo "Updating official packages..."
    if ! progress_run "Update official packages" sudo pacman -Syu --noconfirm; then
        progress_stop
        trap - EXIT INT TERM
        finish_logging
        log_error "pacman update failed"
        return 1
    fi

    # Rebuild Hyprland plugins if Hyprland was updated
    if command -v hyprpm &>/dev/null && pacman -Q hyprland &>/dev/null; then
        echo
        echo "Rebuilding Hyprland plugins..."
        hyprpm update < <(echo "y") 2>&1 || echo "Hyprland plugin rebuild failed (non-critical)"
    fi

    # Rebuild yay if broken (e.g., after libalpm/pacman update)
    rebuild_yay_if_broken

    # Ensure yay is installed for AUR step
    ensure_yay_installed

    # Neutralize npm config that breaks some AUR builds
    local npmrc_backup=""
    if [[ -f "$HOME/.npmrc" ]]; then
        npmrc_backup="$HOME/.npmrc.dotfiles-backup-$(date +%s)"
        mv "$HOME/.npmrc" "$npmrc_backup" 2>/dev/null || true
    fi
    export NPM_CONFIG_USERCONFIG=/dev/null
    unset NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG npm_config_globalconfig

    # Update AUR packages
    echo
    echo "Updating AUR packages..."
    progress_run "Update AUR packages" yay -Sua --noconfirm --answerclean N --answerdiff N || true

    # Restore ~/.npmrc if we moved it
    if [[ -n "$npmrc_backup" && -f "$npmrc_backup" ]]; then
        mv "$npmrc_backup" "$HOME/.npmrc" 2>/dev/null || true
    fi

    # Complete
    trap - EXIT INT TERM
    finish_logging

    progress_complete "System Update"
    export SKIP_PAUSE=1
}
