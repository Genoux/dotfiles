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

    if [[ ${#missing_official[@]} -eq 0 ]]; then
        log_success "All official packages already installed"
        return 0
    fi

    log_info "Installing ${#missing_official[@]} official packages..."

    # First attempt
    local failed=()
    if ! run_command_logged "Install official packages (attempt 1)" sudo pacman -S --needed --noconfirm "${missing_official[@]}"; then
        # Collect failures
        for pkg in "${missing_official[@]}"; do
            if ! pacman -Q "$pkg" &>/dev/null; then
                failed+=("$pkg")
            fi
        done

        if [[ ${#failed[@]} -gt 0 ]]; then
            log_warning "First attempt failed for ${#failed[@]} packages, retrying individually..."

            # Retry each failed package individually
            local retry_failed=()
            for pkg in "${failed[@]}"; do
                log_info "Retrying: $pkg"
                if ! sudo pacman -S --needed --noconfirm "$pkg" 2>&1 | tee -a "${DOTFILES_LOG_FILE:-/dev/null}"; then
                    retry_failed+=("$pkg")
                    log_error "Failed to install: $pkg"
                else
                    log_success "✓ Installed: $pkg"
                fi
            done

            if [[ ${#retry_failed[@]} -gt 0 ]]; then
                log_error "Failed to install ${#retry_failed[@]} official packages:"
                printf '  ✗ %s\n' "${retry_failed[@]}"
                return 1
            fi
        fi
    fi

    log_success "✓ All official packages installed"
    return 0
}
