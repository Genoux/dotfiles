#!/bin/bash
# AUR package installation

# Read aur.package + every static packages/hardware/*-aur.package manifest
# that applies to this machine (via lib/hardware-packages.sh's
# read_hardware_aur_packages, which selects by detected hardware) into
# aur_packages_ref.
read_aur_install_packages() {
    local -n aur_packages_ref=$1

    aur_packages_ref=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^#.*$ ]] && continue
        aur_packages_ref+=("$pkg")
    done < "$AUR_PACKAGES_FILE"

    local hw_aur=()
    read_hardware_aur_packages hw_aur
    aur_packages_ref+=("${hw_aur[@]}")
}

_neutralize_npm_config_for_aur() {
    local -n npmrc_backup_ref=$1

    npmrc_backup_ref=""
    if [[ -f "$HOME/.npmrc" ]]; then
        npmrc_backup_ref="$HOME/.npmrc.aur-install-backup"
        mv "$HOME/.npmrc" "$npmrc_backup_ref" 2>/dev/null || true
    fi

    echo "" > "$HOME/.npmrc"
    export NPM_CONFIG_USERCONFIG=/dev/null
    unset NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG npm_config_globalconfig
}

_restore_npm_config_after_aur() {
    local npmrc_backup="$1"

    if [[ -n "$npmrc_backup" && -f "$npmrc_backup" ]]; then
        mv "$npmrc_backup" "$HOME/.npmrc" 2>/dev/null || true
    else
        rm -f "$HOME/.npmrc" 2>/dev/null || true
    fi
}

# Install every AUR package in one yay transaction. Names are assumed already
# validated by preflight. Stdin is /dev/null rather than piped answers: any
# prompt yay's --answer* flags don't cover (e.g. an unexpected pacman
# conflict resolution question) then fails fast with EOF instead of hanging
# and leaving a stale db.lck (see root cause: nodejs conflict prompt, 2026-09).
install_aur_packages() {
    local -n install_aur_packages_ref=$1

    if [[ ${#install_aur_packages_ref[@]} -eq 0 ]]; then
        log_success "No AUR packages to install"
        return 0
    fi

    sudo -v || {
        log_error "Failed to refresh sudo session for yay installation"
        return 1
    }

    ensure_yay_installed || return $?

    local npmrc_backup=""
    _neutralize_npm_config_for_aur npmrc_backup

    log_info "Installing ${#install_aur_packages_ref[@]} AUR packages..."

    local install_status=0
    run_command_logged "Install AUR packages" \
        yay -S --needed --noconfirm --refresh \
            --answerclean None --answerdiff None --answeredit None \
            --removemake -- "${install_aur_packages_ref[@]}" </dev/null \
        || install_status=$?

    _restore_npm_config_after_aur "$npmrc_backup"

    if [[ $install_status -ne 0 ]]; then
        log_error "AUR package installation failed"
        log_info "Check log file for details: ${DOTFILES_LOG_FILE:-N/A}"
        return 1
    fi

    log_success "✓ All AUR packages installed"
    return 0
}
