#!/bin/bash
# Official repository package installation

# Read arch.package + every static packages/hardware/*.package manifest that
# applies to this machine (via lib/hardware-packages.sh's
# read_hardware_official_packages, which selects by detected hardware) into
# packages_ref.
read_official_install_packages() {
    local -n packages_ref=$1

    packages_ref=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^#.*$ ]] && continue
        packages_ref+=("$pkg")
    done < "$PACKAGES_FILE"

    local hw_official=()
    read_hardware_official_packages hw_official
    packages_ref+=("${hw_official[@]}")
}

# Install every official package in one transaction. Names are assumed
# already validated by preflight (check_package_names) — no per-package
# existence probing or silent-skip fallback here.
install_official_packages() {
    local -n install_packages_ref=$1

    if [[ ${#install_packages_ref[@]} -eq 0 ]]; then
        log_success "No official packages to install"
        return 0
    fi

    log_info "Installing ${#install_packages_ref[@]} official packages..."

    if ! run_command_logged "Sync, upgrade and install official packages" \
        sudo pacman -Syu --needed --noconfirm -- "${install_packages_ref[@]}"; then
        log_error "Official package installation failed"
        log_info "Check log file for details: ${DOTFILES_LOG_FILE:-N/A}"
        return 1
    fi

    log_success "✓ All official packages installed"
    return 0
}
