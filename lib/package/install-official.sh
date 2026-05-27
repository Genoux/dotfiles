#!/bin/bash
# Official repository package installation helpers

read_official_install_packages() {
    local -n packages_ref=$1

    log_info "Filtering packages based on hardware..."

    local filtered_packages
    filtered_packages=$(filter_packages_by_hardware "$PACKAGES_FILE")

    packages_ref=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^#.*$ ]] && continue
        packages_ref+=("$pkg")
    done < "$filtered_packages"

    rm -f "$filtered_packages"
}

install_official_packages() {
    local -n packages_ref=$1
    local missing_official=()

    for pkg in "${packages_ref[@]}"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            if pacman -Ss "^$pkg$" &>/dev/null; then
                missing_official+=("$pkg")
            else
                log_warning "Package $pkg not found in official repositories, skipping"
            fi
        fi
    done

    if [[ ${#missing_official[@]} -gt 0 ]]; then
        if ! run_command_logged "Install ${#missing_official[@]} official packages" sudo pacman -S --needed --noconfirm "${missing_official[@]}"; then
            log_warning "Some official packages failed to install, but continuing..."
        fi
    fi
}
