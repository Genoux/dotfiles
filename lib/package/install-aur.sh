#!/bin/bash

read_aur_install_packages() {
    local -n aur_packages_ref=$1

    aur_packages_ref=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^#.*$ ]] && continue
        aur_packages_ref+=("$pkg")
    done < "$AUR_PACKAGES_FILE"
}

_clean_aur_package_build_dirs() {
    local -n missing_aur_ref=$1

    # Stale yay src trees often break incremental AUR rebuilds after manifest changes.
    for pkg in "${missing_aur_ref[@]}"; do
        if [[ -d "$HOME/.cache/yay/$pkg" ]]; then
            chmod -R +w "$HOME/.cache/yay/$pkg" 2>/dev/null || true
            rm -rf "$HOME/.cache/yay/$pkg"
        fi
    done
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

_detect_aur_conflicts() {
    local -n missing_aur_ref=$1
    local -n conflicts_ref=$2

    conflicts_ref=()

    for pkg in "${missing_aur_ref[@]}"; do
        if [[ "$pkg" == *"-bin" ]]; then
            local base_name="${pkg%-bin}"
            local git_variant="${base_name}-git"

            if pacman -Q "$git_variant" &>/dev/null; then
                conflicts_ref+=("$git_variant")
            fi
            if pacman -Q "$base_name" &>/dev/null; then
                conflicts_ref+=("$base_name")
            fi
        elif [[ "$pkg" == *"-git" ]]; then
            local base_name="${pkg%-git}"
            local bin_variant="${base_name}-bin"

            if pacman -Q "$bin_variant" &>/dev/null; then
                conflicts_ref+=("$bin_variant")
            fi
            if pacman -Q "$base_name" &>/dev/null; then
                conflicts_ref+=("$base_name")
            fi
        fi
    done
}

_remove_safe_aur_conflicts() {
    local -n conflicts_ref=$1

    if [[ ${#conflicts_ref[@]} -eq 0 ]]; then
        return 0
    fi

    local safe_to_remove=()
    local blocked_conflicts=()

    for pkg in "${conflicts_ref[@]}"; do
        local required_by
        required_by=$(pacman -Qi "$pkg" 2>/dev/null | rg "Required By" | cut -d: -f2 | xargs)

        if [[ -z "$required_by" || "$required_by" == "None" ]]; then
            safe_to_remove+=("$pkg")
        else
            blocked_conflicts+=("$pkg (required by: $required_by)")
        fi
    done

    if [[ ${#safe_to_remove[@]} -gt 0 ]]; then
        log_info "Removing ${#safe_to_remove[@]} conflicting package(s)..."
        sudo pacman -Rns --noconfirm "${safe_to_remove[@]}" >/dev/null 2>&1 || true
        echo
    fi

    if [[ ${#blocked_conflicts[@]} -gt 0 ]]; then
        log_warning "Cannot auto-remove these conflicts (dependencies exist):"
        printf '  - %s\n' "${blocked_conflicts[@]}"
        echo
    fi
}

install_aur_packages() {
    local -n aur_packages_ref=$1

    if [[ ${#aur_packages_ref[@]} -eq 0 ]]; then
        return 0
    fi

    [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Refreshing sudo session for yay installation..." >> "$DOTFILES_LOG_FILE"
    sudo -v || {
        log_error "Failed to refresh sudo session for yay installation"
        return 1
    }

    ensure_yay_installed || return $?

    local missing_aur=()
    for pkg in "${aur_packages_ref[@]}"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            missing_aur+=("$pkg")
        fi
    done

    if [[ ${#missing_aur[@]} -eq 0 ]]; then
        return 0
    fi

    _clean_aur_package_build_dirs missing_aur

    local npmrc_backup=""
    _neutralize_npm_config_for_aur npmrc_backup

    local conflicts_to_remove=()
    _detect_aur_conflicts missing_aur conflicts_to_remove
    _remove_safe_aur_conflicts conflicts_to_remove

    [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Refreshing sudo session..." >> "$DOTFILES_LOG_FILE"
    sudo -v || {
        _restore_npm_config_after_aur "$npmrc_backup"
        log_error "Failed to refresh sudo session"
        return 1
    }

    [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Installing packages: ${missing_aur[*]}" >> "$DOTFILES_LOG_FILE"
    [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Starting installation..." >> "$DOTFILES_LOG_FILE"

    # First attempt - batch install
    # yay still prompts for clean/diff review even with --noconfirm; feed defaults non-interactively.
    log_info "Installing ${#missing_aur[@]} AUR packages (attempt 1)..."
    printf '1\nY\n' | yay -S --needed --noconfirm --refresh --answerclean None --answerdiff None --removemake "${missing_aur[@]}"
    local yay_exit_code=$?
    echo

    _restore_npm_config_after_aur "$npmrc_backup"

    # Check which packages actually installed
    local failed=()
    for pkg in "${missing_aur[@]}"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            failed+=("$pkg")
        fi
    done

    # If batch install succeeded or all packages installed, we're done
    if [[ $yay_exit_code -eq 0 ]] || [[ ${#failed[@]} -eq 0 ]]; then
        [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] All packages installed successfully" >> "$DOTFILES_LOG_FILE"
        log_success "✓ All AUR packages installed"
        return 0
    fi

    # Retry failed packages individually
    log_warning "First attempt failed for ${#failed[@]} packages, retrying individually..."
    [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Retrying ${#failed[@]} failed packages individually" >> "$DOTFILES_LOG_FILE"

    local retry_failed=()
    for pkg in "${failed[@]}"; do
        log_info "Retrying: $pkg"

        # Clean build dir for retry
        if [[ -d "$HOME/.cache/yay/$pkg" ]]; then
            chmod -R +w "$HOME/.cache/yay/$pkg" 2>/dev/null || true
            rm -rf "$HOME/.cache/yay/$pkg"
        fi

        # Neutralize npm config again
        local npmrc_backup_retry=""
        _neutralize_npm_config_for_aur npmrc_backup_retry

        # Retry installation
        if printf '1\nY\n' | yay -S --needed --noconfirm --refresh --answerclean None --answerdiff None --removemake "$pkg" 2>&1 | tee -a "${DOTFILES_LOG_FILE:-/dev/null}"; then
            if pacman -Q "$pkg" &>/dev/null; then
                log_success "✓ Installed: $pkg"
            else
                retry_failed+=("$pkg")
                log_error "Failed to install: $pkg (package not found after install)"
            fi
        else
            retry_failed+=("$pkg")
            log_error "Failed to install: $pkg"
        fi

        _restore_npm_config_after_aur "$npmrc_backup_retry"
        echo
    done

    if [[ ${#retry_failed[@]} -gt 0 ]]; then
        log_error "Failed to install ${#retry_failed[@]} AUR packages after retry:"
        printf '  ✗ %s\n' "${retry_failed[@]}"
        [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Final failure count: ${#retry_failed[@]}" >> "$DOTFILES_LOG_FILE"
        log_info "Check log file for details: $DOTFILES_LOG_FILE"
        return 1
    fi

    log_success "✓ All AUR packages installed after retry"
    return 0
}
