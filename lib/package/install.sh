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

# Install everything tracked in packages/arch.package, packages/aur.package
# and the static packages/hardware/*.package manifests selected for this
# machine. Each phase (official, AUR) is a single batched transaction; a
# failure aborts here rather than limping on with a partially-installed
# system.
packages_install() {
    sudo -v || {
        log_error "Failed to obtain sudo privileges"
        return 1
    }

    clear
    packages_prepare

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

    if ! install_official_packages packages; then
        return 1
    fi

    if ! install_aur_packages aur_packages; then
        return 1
    fi

    echo
    source "$DOTFILES_DIR/lib/package/verify.sh"
    if ! verify_package_installation packages "official"; then
        log_error "Official package verification failed"
        return 1
    fi

    if ! verify_package_installation aur_packages "AUR"; then
        log_error "AUR package verification failed"
        return 1
    fi
}
