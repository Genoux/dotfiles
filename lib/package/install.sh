#!/bin/bash
# Package installation orchestration

_validate_package_files() {
    if [[ ! -f "$PACKAGES_FILE" ]]; then
        fatal_error "packages/arch.package not found in $DOTFILES_DIR"
    fi

    if [[ ! -f "$AUR_PACKAGES_FILE" ]]; then
        fatal_error "packages/aur.package not found in $DOTFILES_DIR"
    fi
}

packages_install() {
    ensure_sudo || {
        log_error "Failed to obtain sudo privileges"
        return 1
    }

    packages_prepare || return 1

    log_section "Installing Packages"

    _validate_package_files

    # Populated and read via `local -n` in the read_/install_/verify_
    # functions below, not referenced by name here.
    # shellcheck disable=SC2034
    local packages=()
    # shellcheck disable=SC2034
    local aur_packages=()

    read_official_install_packages packages
    read_aur_install_packages aur_packages

    source "$DOTFILES_DIR/lib/package/verify.sh"
    if [[ "${1:-all}" != "aur" ]]; then
        install_official_packages packages || return 1
        verify_package_installation packages "official" || return 1
    fi

    if [[ "${1:-all}" != "official" ]]; then
        run_logged "$DOTFILES_DIR/install/system/makepkg.sh" || return 1
        install_aur_packages aur_packages || return 1
        verify_package_installation aur_packages "AUR" || return 1
    fi
    return 0
}
