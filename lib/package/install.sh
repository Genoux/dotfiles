#!/bin/bash
# Package installation orchestration

_remove_debug_packages_before_install() {
    local debug_packages
    debug_packages=$(pacman -Qq | grep '\-debug$' 2>/dev/null || true)

    if [[ -n "$debug_packages" ]]; then
        echo "$debug_packages" | xargs sudo pacman -Rdd --noconfirm >/dev/null 2>&1 || true
    fi
}

_validate_package_files() {
    if [[ ! -f "$PACKAGES_FILE" ]]; then
        fatal_error "packages/arch.package not found in $DOTFILES_DIR"
    fi

    if [[ ! -f "$AUR_PACKAGES_FILE" ]]; then
        fatal_error "packages/aur.package not found in $DOTFILES_DIR"
    fi
}

packages_install() {
    sudo -v || {
        log_error "Failed to obtain sudo privileges"
        return 1
    }

    clear
    packages_prepare

    log_section "Installing Packages"

    _remove_debug_packages_before_install
    _validate_package_files

    local packages=()
    local aur_packages=()

    read_official_install_packages packages
    read_aur_install_packages aur_packages

    if ! run_command_logged "Sync package databases" sudo pacman -Sy --noconfirm; then
        log_error "Failed to sync package databases"
        return 1
    fi

    install_official_packages packages
    install_aur_packages aur_packages || return $?

    echo
    package_install_audit packages aur_packages
}
