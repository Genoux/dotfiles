#!/bin/bash
# System package updates and conflict resolution

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

    run_command_logged "Update AUR packages" yay -Sua --noconfirm --answerclean N --answerdiff N || true

    # Restore ~/.npmrc if we moved it
    if [[ -n "$npmrc_backup" && -f "$npmrc_backup" ]]; then
        mv "$npmrc_backup" "$HOME/.npmrc" 2>/dev/null || true
    fi

    finish_logging
    sleep 1
    stop_log_monitor true

    log_success "System update complete"
}
