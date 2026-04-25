#!/bin/bash
# System package updates and conflict resolution

# Fix corrupted OPTIONS array in makepkg.conf (multiple ! before an option is invalid)
fix_makepkg_options() {
    if sudo grep -qE '!{2,}' /etc/makepkg.conf 2>/dev/null; then
        log_warning "Fixing corrupted OPTIONS in /etc/makepkg.conf"
        sudo sed -i -E 's/!+([a-z])/!\1/g' /etc/makepkg.conf
    fi
}

# Remove installed -git packages that conflict with their official counterparts
# These block official packages from being installed as dependencies during upgrades
remove_conflicting_git_packages() {
    local to_remove=()

    while IFS= read -r git_pkg; do
        local base_pkg="${git_pkg%-git}"
        # Official package exists in repos but isn't installed (-git is replacing it)
        if pacman -Si "$base_pkg" &>/dev/null 2>&1 && ! pacman -Q "$base_pkg" &>/dev/null 2>&1; then
            to_remove+=("$git_pkg")
        fi
    done < <(pacman -Qq 2>/dev/null | grep '\-git$')

    [[ ${#to_remove[@]} -eq 0 ]] && return 0

    log_warning "Removing git packages superseded by official packages: ${to_remove[*]}"
    sudo pacman -Rdd --noconfirm "${to_remove[@]}" || true
}

# Rebuild yay if it's broken (e.g., after libalpm update)
rebuild_yay_if_broken() {
    if ! command -v yay &>/dev/null; then
        return 0
    fi

    if yay --version &>/dev/null; then
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
    return 0
}

# Update system packages
packages_update() {
    # Validate sudo access upfront
    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges"
        return 1
    fi

    # Initialize logging and start monitor
    init_logging "package"
    start_log_monitor

    # Fix makepkg.conf if OPTIONS array is corrupted
    fix_makepkg_options

    # Remove leftover temp download dirs from previous interrupted updates
    run_command_logged "Remove temp downloads" bash -c '
        count=$(find /var/cache/pacman/pkg -maxdepth 1 -name "download-*" -type d 2>/dev/null | wc -l)
        if [[ "$count" -gt 0 ]]; then
            sudo find /var/cache/pacman/pkg -maxdepth 1 -name "download-*" -type d -exec rm -rf {} + 2>/dev/null || true
            echo "Removed $count leftover temp dirs"
        else
            echo "None found"
        fi
    '

    # If disk space < 3GB, auto-clean old package cache to make room
    local free_blocks
    free_blocks=$(df / | tail -1 | awk '{print $4}')
    if [[ "$free_blocks" -lt 3145728 ]]; then
        log_warning "Low disk space, cleaning package cache..."
        run_command_logged "Free disk space" bash -c '
            if command -v paccache &>/dev/null; then
                sudo paccache -rk1 --noconfirm 2>/dev/null || true
                sudo paccache -ruk0 --noconfirm 2>/dev/null || true
            else
                sudo pacman -Sc --noconfirm 2>/dev/null || true
            fi
        '
    fi

    # Remove -git packages that would conflict with official packages during upgrade
    remove_conflicting_git_packages

    # Remove debug packages first (silent if none found)
    local debug_packages=$(pacman -Qq | grep '\-debug$' 2>/dev/null || true)
    if [[ -n "$debug_packages" ]]; then
        run_command_logged "Remove debug packages" bash -c "echo '$debug_packages' | xargs sudo pacman -Rdd --noconfirm" || true
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Remove debug packages" >> "$DOTFILES_LOG_FILE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: No debug packages to remove" >> "$DOTFILES_LOG_FILE"
    fi

    # Sync package database
    if ! run_command_logged "Sync package database" sudo pacman -Sy --noconfirm; then
        finish_logging
        sleep 1
        stop_log_monitor
        log_error "Failed to sync package database"
        return 1
    fi

    # Update official packages
    if ! run_command_logged "Update official packages" sudo pacman -Su --noconfirm; then
        finish_logging
        sleep 1
        stop_log_monitor
        log_error "pacman update failed"
        return 1
    fi

    # Rebuild yay if broken (e.g., after libalpm/pacman update)
    rebuild_yay_if_broken

    # Ensure yay is installed for AUR step
    ensure_yay_installed

    # Update AUR packages
    # Neutralize npm config that breaks some AUR builds
    local npmrc_backup=""
    if [[ -f "$HOME/.npmrc" ]]; then
        npmrc_backup="$HOME/.npmrc.dotfiles-backup-$(date +%s)"
        mv "$HOME/.npmrc" "$npmrc_backup" 2>/dev/null || true
    fi
    export NPM_CONFIG_USERCONFIG=/dev/null
    unset NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG npm_config_globalconfig

    # On failure, purge downloaded source tarballs (corrupted checksums) and retry with clean build dirs
    if ! run_command_logged "Update AUR packages" yay -Sua --noconfirm --answerclean N --answerdiff N; then
        log_warning "AUR update failed, purging source cache and retrying..."
        find "$HOME/.cache/yay" -maxdepth 2 \( -name "*.tar.gz" -o -name "*.tar.xz" -o -name "*.tar.zst" -o -name "*.zip" \) -delete 2>/dev/null || true
        run_command_logged "Update AUR packages (clean retry)" yay -Sua --noconfirm --answerclean A --answerdiff N || true
    fi

    # Restore ~/.npmrc if we moved it
    if [[ -n "$npmrc_backup" && -f "$npmrc_backup" ]]; then
        mv "$npmrc_backup" "$HOME/.npmrc" 2>/dev/null || true
    fi

    finish_logging
    sleep 1
    stop_log_monitor true

    log_success "System update complete"
}
