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

# yay's --useask resolves replacement conflicts (e.g. cliamp -> cliamp-bin)
# inside the transaction: https://github.com/Jguer/yay/blob/next/doc/yay.8
install_aur_packages() {
    local -n install_aur_packages_ref=$1

    if [[ ${#install_aur_packages_ref[@]} -eq 0 ]]; then
        log_success "No AUR packages to install"
        return 0
    fi

    ensure_sudo || {
        log_error "Failed to refresh sudo session for yay installation"
        return 1
    }

    ensure_yay_installed || return $?

    local targets=() pkg
    for pkg in "${install_aur_packages_ref[@]}"; do
        if [[ "$pkg" == "yay" ]] && pacman -Qq yay &>/dev/null; then
            log_info "Keeping the installed yay provider"
        else
            targets+=("$pkg")
        fi
    done
    (( ${#targets[@]} > 0 )) || return 0

    log_info "Installing ${#targets[@]} AUR packages..."

    local install_status=0
    run_command_logged "Install AUR packages" \
        env -u NPM_CONFIG_PREFIX -u npm_config_prefix -u NPM_CONFIG_GLOBALCONFIG -u npm_config_globalconfig \
            NPM_CONFIG_USERCONFIG=/dev/null npm_config_userconfig=/dev/null yay -S --needed --noconfirm --useask --batchinstall=false \
            --answerclean None --answerdiff None --answeredit None \
            --removemake -- "${targets[@]}" </dev/null \
        || install_status=$?

    if [[ $install_status -ne 0 ]]; then
        log_error "AUR package installation failed"
        log_info "Check log file for details: ${DOTFILES_LOG_FILE:-N/A}"
        return 1
    fi

    log_success "✓ All AUR packages installed"
    return 0
}
