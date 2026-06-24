#!/bin/bash
# Package installation verification

# Verify packages were actually installed
verify_package_installation() {
    local -n expected_packages=$1
    local package_type="${2:-official}"

    local missing=()
    local failed=()

    for pkg in "${expected_packages[@]}"; do
        if ! pacman -Qq "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Installation verification failed for $package_type packages:"
        printf '  ✗ %s\n' "${missing[@]}"
        return 1
    fi

    log_success "✓ All $package_type packages verified (${#expected_packages[@]} packages)"
    return 0
}

# Verify critical packages
verify_critical_packages() {
    local critical_packages=(
        "hyprland"
        "kitty"
        "waybar"
        "quickshell"
        "stow"
        "gum"
        "yay"
    )

    local missing=()

    for pkg in "${critical_packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null && ! pacman -Qq "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        fatal_error "Critical packages missing: ${missing[*]}"
        return 1
    fi

    log_success "✓ All critical packages installed"
    return 0
}

# Verify config links
verify_config_links() {
    local expected_configs=(
        "hypr"
        "kitty"
        "waybar"
        "quickshell"
        "shell"
    )

    local missing=()

    source "$DOTFILES_DIR/lib/config.sh"

    for config in "${expected_configs[@]}"; do
        if ! is_config_linked "$config"; then
            missing+=("$config")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Config links missing: ${missing[*]}"
        return 1
    fi

    log_success "✓ All critical configs linked"
    return 0
}

# Verify theme setup
verify_theme_setup() {
    local theme_files=(
        "$HOME/.config/quickshell/config/theme.qml"
        "$HOME/.config/ags/styles/abstracts/_theme.scss"
    )

    local missing=()

    for file in "${theme_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing+=("${file/#$HOME/~}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warning "Theme files missing: ${missing[*]}"
        log_info "Run: dotfiles theme install-gtk"
        return 1
    fi

    log_success "✓ Theme files present"
    return 0
}

# Run full verification
run_full_verification() {
    log_section "Installation Verification"

    local failed=0

    # Verify critical packages
    if ! verify_critical_packages; then
        ((failed++))
    fi
    echo

    # Verify config links
    if ! verify_config_links; then
        ((failed++))
    fi
    echo

    # Verify theme setup
    if ! verify_theme_setup; then
        ((failed++))
    fi
    echo

    if [[ $failed -gt 0 ]]; then
        log_error "Verification failed with $failed issues"
        log_info "Run 'dotfiles install' to fix issues"
        return 1
    fi

    log_success "✓ Installation verification passed"
    return 0
}
