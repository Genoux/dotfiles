#\!/bin/bash
# Package installation operations
# Install packages from lists
packages_install() {
    # Get sudo first (will prompt for password)
    sudo -v || {
        log_error "Failed to obtain sudo privileges"
        return 1
    }

    clear

    # Always prepare system first
    packages_prepare

    log_section "Installing Packages"

    # Remove all debug packages first to avoid conflicts (silent if none found)
    local debug_packages=$(pacman -Qq | grep '\-debug$' 2>/dev/null || true)
    if [[ -n "$debug_packages" ]]; then
        echo "$debug_packages" | xargs sudo pacman -Rdd --noconfirm >/dev/null 2>&1 || true
    fi

    # Check if package files exist
    if [[ ! -f "$PACKAGES_FILE" ]]; then
        fatal_error "packages/arch.package not found in $DOTFILES_DIR"
    fi

    if [[ ! -f "$AUR_PACKAGES_FILE" ]]; then
        fatal_error "packages/aur.package not found in $DOTFILES_DIR"
    fi
    
    # Filter packages by hardware
    log_info "Filtering packages based on hardware..."
    local filtered_packages=$(filter_packages_by_hardware "$PACKAGES_FILE")
    
    # Read filtered official packages
    local packages=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^#.*$ ]] && continue
        packages+=("$pkg")
    done < "$filtered_packages"
    
    # Clean up temp file
    rm -f "$filtered_packages"
    
    # Read AUR packages
    local aur_packages=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^#.*$ ]] && continue
        aur_packages+=("$pkg")
    done < "$AUR_PACKAGES_FILE"
    
    # Update package databases (log monitor already started by packages_prepare)
    if ! run_command_logged "Sync package databases" sudo pacman -Sy --noconfirm; then
        log_error "Failed to sync package databases"
        return 1
    fi
    
    # Just install packages from lists - no checking
    # For auditing system vs dotfiles, use package_audit function instead

    # Find missing official packages (filter out packages that don't exist in official repos)
    local missing_official=()
    for pkg in "${packages[@]}"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            # Check if package exists in official repositories
            if pacman -Ss "^$pkg$" &>/dev/null; then
                missing_official+=("$pkg")
            else
                log_warning "Package $pkg not found in official repositories, skipping"
            fi
        fi
    done
    
    # Install missing official packages
    if [[ ${#missing_official[@]} -gt 0 ]]; then
        if ! run_command_logged "Install ${#missing_official[@]} official packages" sudo pacman -S --needed --noconfirm "${missing_official[@]}"; then
            log_warning "Some official packages failed to install, but continuing..."
        fi
    fi
    

    # Ensure yay is installed for AUR packages
    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        # Refresh sudo session before installing yay (makepkg needs sudo)
        [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Refreshing sudo session for yay installation..." >> "$DOTFILES_LOG_FILE"
        sudo -v || {
            log_error "Failed to refresh sudo session for yay installation"
            return 1
        }
        ensure_yay_installed

        # Find missing AUR packages first
        local missing_aur=()
        for pkg in "${aur_packages[@]}"; do
            if ! pacman -Q "$pkg" &>/dev/null; then
                missing_aur+=("$pkg")
            fi
        done
        
        # Exit early if nothing to install
        if [[ ${#missing_aur[@]} -eq 0 ]]; then
            return 0
        fi
        
        # Pre-installation cleanup for common AUR build issues (silent)
        # 1. Clean Go module cache permission issues
        if command -v go &>/dev/null; then
            for pkg in "${missing_aur[@]}"; do
                if [[ -d "$HOME/.cache/yay/$pkg" ]]; then
                    chmod -R +w "$HOME/.cache/yay/$pkg" 2>/dev/null || true
                    rm -rf "$HOME/.cache/yay/$pkg"
                fi
            done
        fi

        # 2. Temporarily neutralize npm config
        local npmrc_backup=""
        if [[ -f "$HOME/.npmrc" ]]; then
            npmrc_backup="$HOME/.npmrc.aur-install-backup"
            mv "$HOME/.npmrc" "$npmrc_backup" 2>/dev/null || true
        fi

        echo "" > "$HOME/.npmrc"
        export NPM_CONFIG_USERCONFIG=/dev/null
        unset NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG npm_config_globalconfig
        
        # Resolve package conflicts
        local conflicts_to_remove=()

        # Special case: Migrate elephant-bin to elephant (Go version compatibility)
        if printf '%s\n' "${missing_aur[@]}" | grep -q '^elephant$'; then
            if pacman -Q elephant-bin &>/dev/null; then
                conflicts_to_remove+=("elephant-bin")
            fi
        fi
        for pkg in "${missing_aur[@]}"; do
            # Check for common conflicts (e.g., walker-bin vs walker-git, or base vs -bin/-git)
            if [[ "$pkg" == *"-bin" ]]; then
                local base_name="${pkg%-bin}"
                local git_variant="${base_name}-git"
                if pacman -Q "$git_variant" &>/dev/null; then
                    conflicts_to_remove+=("$git_variant")
                fi
                if pacman -Q "$base_name" &>/dev/null; then
                    conflicts_to_remove+=("$base_name")
                fi
            elif [[ "$pkg" == *"-git" ]]; then
                local base_name="${pkg%-git}"
                local bin_variant="${base_name}-bin"
                if pacman -Q "$bin_variant" &>/dev/null; then
                    conflicts_to_remove+=("$bin_variant")
                fi
                if pacman -Q "$base_name" &>/dev/null; then
                    conflicts_to_remove+=("$base_name")
                fi
            fi
        done

        # Remove conflicting packages before installation (only show if conflicts found)
        if [[ ${#conflicts_to_remove[@]} -gt 0 ]]; then
            # Filter out packages that are required by others
            local safe_to_remove=()
            local blocked_conflicts=()

            for pkg in "${conflicts_to_remove[@]}"; do
                local required_by=$(pacman -Qi "$pkg" 2>/dev/null | grep "Required By" | cut -d: -f2 | xargs)

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
        fi
        
        # Refresh sudo session before yay (yay calls pacman which needs sudo)
        [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Refreshing sudo session..." >> "$DOTFILES_LOG_FILE"
        sudo -v || {
            log_error "Failed to refresh sudo session"
            return 1
        }

        # Install AUR packages directly (yay will handle sudo prompts)
        [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Installing packages: ${missing_aur[*]}" >> "$DOTFILES_LOG_FILE"
        [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Starting installation..." >> "$DOTFILES_LOG_FILE"

        printf '1\nY\n' | yay -S --needed --noconfirm --refresh --answerclean None --answerdiff None --removemake ${missing_aur[*]}
        local yay_exit_code=$?
        echo

        # Restore ~/.npmrc if we moved it, or remove the temporary empty one
        if [[ -n "$npmrc_backup" && -f "$npmrc_backup" ]]; then
            mv "$npmrc_backup" "$HOME/.npmrc" 2>/dev/null || true
        else
            # Remove the temporary empty .npmrc we created
            rm -f "$HOME/.npmrc" 2>/dev/null || true
        fi

        if [[ $yay_exit_code -ne 0 ]]; then
            [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Installation completed with some failures (exit code: $yay_exit_code)" >> "$DOTFILES_LOG_FILE"
            log_warning "Some AUR packages failed to install, but continuing..."
            echo
            log_info "Check log file for details: $DOTFILES_LOG_FILE"
        else
            [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Installation completed successfully" >> "$DOTFILES_LOG_FILE"
        fi
        echo
    fi
    
    echo
    
    # Quick dependency check: Only check EXPLICITLY installed packages not in dotfiles
    local explicit_count=$(pacman -Qeq | wc -l)
    
    # Skip if too many packages (would take too long)
    if [[ $explicit_count -gt 500 ]]; then
        :  # Skip dependency check
    else
        local deps_to_add_official=()
        local deps_to_add_aur=()
        
        # Get all packages in dotfiles (convert to associative array for O(1) lookup)
        declare -A dotfiles_map
        for pkg in "${packages[@]}" "${aur_packages[@]}"; do
            dotfiles_map[$pkg]=1
        done
        
        # Only check explicitly installed packages (much smaller set)
        while IFS= read -r installed_pkg; do
            # Skip if already in dotfiles
            [[ -n "${dotfiles_map[$installed_pkg]}" ]] && continue
            
            # Quick check: is this required by any package in dotfiles?
            local required_by=$(pacman -Qi "$installed_pkg" 2>/dev/null | awk '/^Required By/ {for(i=4;i<=NF;i++) print $i}')
            
            if [[ -n "$required_by" ]]; then
                # Check if any requirer is in our dotfiles
                local should_add=false
                while read -r req; do
                    if [[ -n "${dotfiles_map[$req]}" ]]; then
                        should_add=true
                        break
                    fi
                done <<< "$required_by"
                
                if $should_add; then
                    # Determine if it's AUR or official (batch check)
                    if pacman -Qm "$installed_pkg" &>/dev/null; then
                        deps_to_add_aur+=("$installed_pkg")
                    else
                        deps_to_add_official+=("$installed_pkg")
                    fi
                fi
            fi
        done < <(pacman -Qeq)  # Only explicitly installed packages
    
        # Add missing dependencies to dotfiles
        if [[ ${#deps_to_add_official[@]} -gt 0 || ${#deps_to_add_aur[@]} -gt 0 ]]; then
            log_info "Found dependencies to add to dotfiles:"
            [[ ${#deps_to_add_official[@]} -gt 0 ]] && printf '  - %s (official)\n' "${deps_to_add_official[@]}"
            [[ ${#deps_to_add_aur[@]} -gt 0 ]] && printf '  - %s (aur)\n' "${deps_to_add_aur[@]}"
            echo
            
            for dep in "${deps_to_add_official[@]}"; do
                echo "$dep" >> "$PACKAGES_FILE"
            done
            
            for dep in "${deps_to_add_aur[@]}"; do
                echo "$dep" >> "$AUR_PACKAGES_FILE"
            done
            
            sort -u "$PACKAGES_FILE" -o "$PACKAGES_FILE"
            sort -u "$AUR_PACKAGES_FILE" -o "$AUR_PACKAGES_FILE"
        fi
    fi
    
    # Check for any outdated packages
    local outdated_official=$(pacman -Qu 2>/dev/null | grep -v "\[ignored\]" | wc -l)
    local outdated_aur=$(yay -Qua 2>/dev/null | wc -l)

    if [[ $outdated_official -gt 0 || $outdated_aur -gt 0 ]]; then
        echo
        log_warning "Found $outdated_official official + $outdated_aur AUR packages with updates available"
        log_info "Run 'yay -Syu' or use the update menu option to upgrade"
        echo
    fi
}
