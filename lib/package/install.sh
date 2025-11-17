#\!/bin/bash
# Package installation operations
# Install packages from lists
packages_install() {
    # Always prepare system first
    packages_prepare

    log_section "Installing Packages"

    # Remove all debug packages first to avoid conflicts
    local debug_packages=$(pacman -Qq | grep '\-debug$' 2>/dev/null || true)
    if [[ -n "$debug_packages" ]]; then
        log_info "Removing debug packages to avoid conflicts..."
        echo "$debug_packages" | xargs sudo pacman -Rdd --noconfirm 2>/dev/null || true
        echo
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
    
    log_info "Found ${#packages[@]} official packages and ${#aur_packages[@]} AUR packages"
    echo

    # Update package databases to ensure latest versions
    log_info "Updating package databases..."
    sudo pacman -Sy --noconfirm
    echo
    
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
        log_info "Installing ${#missing_official[@]} official packages..."
        echo
        log_info "Packages to install: ${missing_official[*]}"
        echo
        log_info "Installing official packages..."
        echo
        # Install packages directly (sudo will prompt for password if needed)
        [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PACMAN] Installing packages: ${missing_official[*]}" >> "$DOTFILES_LOG_FILE"
        [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PACMAN] Starting installation..." >> "$DOTFILES_LOG_FILE"
        
        # Run pacman with automatic answers to all prompts
        # Use printf to automatically answer provider selection (default=1) and proceed (Y)
        printf "1\nY\n" | sudo pacman -S --needed --noconfirm "${missing_official[@]}"
        local pacman_exit_code=$?
        
        if [[ $pacman_exit_code -eq 0 ]]; then
            [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PACMAN] Installation completed successfully" >> "$DOTFILES_LOG_FILE"
            log_success "Official packages installed"
        else
            [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PACMAN] Installation completed with some failures (exit code: $pacman_exit_code)" >> "$DOTFILES_LOG_FILE"
            log_warning "Some official packages failed to install, but continuing..."
            echo
            log_info "You can try installing failed packages manually later with:"
            log_info "sudo pacman -S <package-name>"
        fi
        echo
    else
        log_success "All official packages already installed"
    fi
    
    echo

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
            log_success "All AUR packages already installed"
            return 0
        fi
        
        # Pre-installation cleanup for common AUR build issues
        log_info "Preparing AUR build environment..."
        echo
        
        # 1. Clean Go module cache permission issues (affects: wego, etc.)
        if command -v go &>/dev/null; then
            log_info "Cleaning Go-based package caches (fixing permissions)..."
            for pkg in "${missing_aur[@]}"; do
                if [[ -d "$HOME/.cache/yay/$pkg" ]]; then
                    # Go modules are read-only, make writable first
                    chmod -R +w "$HOME/.cache/yay/$pkg" 2>/dev/null || true
                    rm -rf "$HOME/.cache/yay/$pkg"
                fi
            done
        fi
        
        # 2. Temporarily neutralize npm config
        local npmrc_backup=""
        if [[ -f "$HOME/.npmrc" ]]; then
            npmrc_backup="$HOME/.npmrc.aur-install-backup"
            log_info "Temporarily moving ~/.npmrc to avoid nvm conflicts..."
            mv "$HOME/.npmrc" "$npmrc_backup" 2>/dev/null || true
        fi

        # Also create a temporary empty .npmrc to override any existing config
        echo "" > "$HOME/.npmrc"

        # Export env vars to neutralize npm config
        export NPM_CONFIG_USERCONFIG=/dev/null
        unset NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG npm_config_globalconfig
        echo
        
        # Resolve package conflicts
        local conflicts_to_remove=()

        # Special case: Migrate elephant-bin to elephant (Go version compatibility)
        if printf '%s\n' "${missing_aur[@]}" | grep -q '^elephant$'; then
            if pacman -Q elephant-bin &>/dev/null; then
                log_warning "Found elephant-bin (pre-compiled binary)"
                log_info "Switching to elephant (source build) for Go version compatibility"
                conflicts_to_remove+=("elephant-bin")
            fi
        fi
        for pkg in "${missing_aur[@]}"; do
            # Check for common conflicts (e.g., walker-bin vs walker-git, or base vs -bin/-git)
            if [[ "$pkg" == *"-bin" ]]; then
                local base_name="${pkg%-bin}"
                local git_variant="${base_name}-git"
                # Check for -git variant
                if pacman -Q "$git_variant" &>/dev/null; then
                    log_info "Detected conflict: $git_variant installed, but $pkg requested"
                    conflicts_to_remove+=("$git_variant")
                fi
                # Check for base package
                if pacman -Q "$base_name" &>/dev/null; then
                    log_info "Detected conflict: $base_name installed, but $pkg requested"
                    conflicts_to_remove+=("$base_name")
                fi
            elif [[ "$pkg" == *"-git" ]]; then
                local base_name="${pkg%-git}"
                local bin_variant="${base_name}-bin"
                # Check for -bin variant
                if pacman -Q "$bin_variant" &>/dev/null; then
                    log_info "Detected conflict: $bin_variant installed, but $pkg requested"
                    conflicts_to_remove+=("$bin_variant")
                fi
                # Check for base package
                if pacman -Q "$base_name" &>/dev/null; then
                    log_info "Detected conflict: $base_name installed, but $pkg requested"
                    conflicts_to_remove+=("$base_name")
                fi
            fi
        done
        
        # Remove conflicting packages before installation
        if [[ ${#conflicts_to_remove[@]} -gt 0 ]]; then
            log_info "Resolving package conflicts..."

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
                printf '  - %s\n' "${safe_to_remove[@]}"
                echo
                # Use sudo pacman directly with --noconfirm to avoid prompts
                sudo pacman -Rns --noconfirm "${safe_to_remove[@]}" 2>/dev/null || true
                echo
            fi

            if [[ ${#blocked_conflicts[@]} -gt 0 ]]; then
                log_warning "Cannot auto-remove these conflicts (dependencies exist):"
                printf '  - %s\n' "${blocked_conflicts[@]}"
                echo
                log_info "You'll need to manually resolve these before installation can proceed"
                echo
            fi
        fi
        
        # Install missing AUR packages
        log_info "Installing ${#missing_aur[@]} AUR packages..."
        echo
        log_info "Packages to install: ${missing_aur[*]}"
        echo
        log_info "Installing AUR packages..."
        echo
        # Refresh sudo session before yay (yay calls pacman which needs sudo)
        [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Refreshing sudo session..." >> "$DOTFILES_LOG_FILE"
        sudo -v || {
            log_error "Failed to refresh sudo session"
            return 1
        }
        
        # Install AUR packages directly (yay will handle sudo prompts)
        [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Installing packages: ${missing_aur[*]}" >> "$DOTFILES_LOG_FILE"
        [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Starting installation..." >> "$DOTFILES_LOG_FILE"
        
        # Run yay with automatic answers to all prompts
        # Use printf to automatically answer any provider selections and proceed confirmations
        # --refresh: Download fresh package databases from AUR
        printf "1\nY\n" | yay -S --needed --noconfirm --refresh --answerclean None --answerdiff None --removemake "${missing_aur[@]}"
        local yay_exit_code=$?
        
        # Restore ~/.npmrc if we moved it, or remove the temporary empty one
        if [[ -n "$npmrc_backup" && -f "$npmrc_backup" ]]; then
            log_info "Restoring ~/.npmrc..."
            mv "$npmrc_backup" "$HOME/.npmrc" 2>/dev/null || true
        else
            # Remove the temporary empty .npmrc we created
            rm -f "$HOME/.npmrc" 2>/dev/null || true
        fi
        
        if [[ $yay_exit_code -eq 0 ]]; then
            [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Installation completed successfully" >> "$DOTFILES_LOG_FILE"
            log_success "AUR packages installed"
        else
            [[ -n "${DOTFILES_LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Installation completed with some failures (exit code: $yay_exit_code)" >> "$DOTFILES_LOG_FILE"
            log_warning "Some AUR packages failed to install, but continuing..."
            echo
            log_info "You can try installing failed packages manually later with:"
            log_info "yay -S <package-name>"
        fi
        echo
    fi
    
    echo
    
    # Quick dependency check: Only check EXPLICITLY installed packages not in dotfiles
    local explicit_count=$(pacman -Qeq | wc -l)
    
    # Skip if too many packages (would take too long)
    if [[ $explicit_count -gt 500 ]]; then
        log_info "Skipping dependency check ($explicit_count packages - would take too long)"
        log_info "Dependencies will be added automatically when needed"
    else
        log_info "Checking for missing dependencies in dotfiles..."
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
            
            log_success "Added $((${#deps_to_add_official[@]} + ${#deps_to_add_aur[@]})) dependencies to dotfiles"
        else
            log_success "All dependencies are already in dotfiles"
        fi
    fi
    
    echo
    log_success "Package installation complete"
    
    # Check for any outdated packages
    log_info "Checking for package updates..."
    local outdated_official=$(pacman -Qu 2>/dev/null | grep -v "\[ignored\]" | wc -l)
    local outdated_aur=$(yay -Qua 2>/dev/null | wc -l)
    
    if [[ $outdated_official -gt 0 || $outdated_aur -gt 0 ]]; then
        echo
        log_warning "Found $outdated_official official + $outdated_aur AUR packages with updates available"
        log_info "Run 'yay -Syu' or use the update menu option to upgrade"
    else
        log_success "All packages are up to date"
    fi
    echo
}
