#!/bin/bash
# System package updates

# Rebuild yay if it's broken (e.g., after libalpm update)
rebuild_yay_if_broken() {
    if ! command -v yay &>/dev/null || yay --version &>/dev/null; then
        return 0
    fi

    log_warning "yay is broken (likely due to library update), rebuilding..."

    if ! run_command_logged "Rebuild yay" bash -c '
        cd /tmp
        rm -rf yay
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
    '; then
        log_error "Failed to rebuild yay"
        return 1
    fi

    log_success "yay rebuilt successfully"
}

# Parse the log file for packages that pacman wants to remove due to conflicts
# Matches lines like: "Remove geocode-glib-common? [y/N]"
_detect_conflict_packages() {
    grep -oP "Remove \K[a-zA-Z0-9@._+:-]+" "$DOTFILES_LOG_FILE" 2>/dev/null | sort -u
}

# Remove old cached packages, keeping one version per package for rollback
_clean_package_cache() {
    sudo paccache -rk1 -q 2>/dev/null || true
    sudo paccache -ruk0 -q 2>/dev/null || true
}

# Update system packages (official + AUR)
packages_update() {
    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges"
        return 1
    fi

    init_logging "package"
    start_log_monitor

    _clean_package_cache

    # yay may be broken after a libalpm/pacman upgrade — fix it before using it
    rebuild_yay_if_broken
    ensure_yay_installed

    # Neutralize npm config that breaks some AUR builds
    local npmrc_backup=""
    if [[ -f "$HOME/.npmrc" ]]; then
        npmrc_backup="$HOME/.npmrc.dotfiles-backup-$(date +%s)"
        mv "$HOME/.npmrc" "$npmrc_backup" 2>/dev/null || true
    fi
    export NPM_CONFIG_USERCONFIG=/dev/null
    unset NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG npm_config_globalconfig

    local update_failed=false

    # yay -Syu syncs the DB and updates both official and AUR packages in one pass
    if ! run_command_logged "Update system and AUR packages" yay -Syu --noconfirm --answerclean N --answerdiff N; then
        # Check if the failure is due to package conflicts (pacman prompts "Remove X? [y/N]"
        # which --noconfirm answers No, causing the transaction to abort)
        local -a conflicts=()
        mapfile -t conflicts < <(_detect_conflict_packages)

        if [[ ${#conflicts[@]} -gt 0 ]]; then
            log_warning "Removing conflicting packages: ${conflicts[*]}"
            sudo pacman -Rdd --noconfirm "${conflicts[@]}" 2>&1 | tee -a "$DOTFILES_LOG_FILE" || true

            if ! run_command_logged "Update system and AUR packages (after conflict resolution)" yay -Syu --noconfirm --answerclean N --answerdiff N; then
                update_failed=true
            fi
        else
            # Non-conflict failure — purge cached source tarballs (corrupted checksums) and retry
            log_warning "Update failed, purging source cache and retrying..."
            find "$HOME/.cache/yay" -maxdepth 2 \( -name "*.tar.gz" -o -name "*.tar.xz" -o -name "*.tar.zst" -o -name "*.zip" \) -delete 2>/dev/null || true

            if ! run_command_logged "Update system and AUR packages (clean retry)" yay -Syu --noconfirm --answerclean A --answerdiff N; then
                update_failed=true
            fi
        fi
    fi

    # Restore ~/.npmrc
    if [[ -n "$npmrc_backup" && -f "$npmrc_backup" ]]; then
        mv "$npmrc_backup" "$HOME/.npmrc" 2>/dev/null || true
    fi

    finish_logging
    sleep 1

    if $update_failed; then
        stop_log_monitor
        log_error "System update failed"
        return 1
    fi

    stop_log_monitor true
    log_success "System update complete"
}
