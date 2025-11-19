#\!/bin/bash
# Interactive package management and cleanup
# Requires: gum (charmbracelet/gum)

# Comprehensive package management (handle all sync scenarios)
packages_manage() {
    log_section "Package Management"

    log_info "Analyzing packages..."

    # Fast categorization: just use pacman's built-in categorization
    local installed_official=()
    local installed_aur=()

    # Get official packages (explicitly installed, not from AUR)
    while IFS= read -r pkg; do
        installed_official+=("$pkg")
    done < <(pacman -Qeq | grep -vf <(pacman -Qmq))

    # Get AUR packages (explicitly installed from AUR)
    while IFS= read -r pkg; do
        installed_aur+=("$pkg")
    done < <(pacman -Qmq)

    # Read dotfiles packages (with hardware filtering)
    local dotfiles_official=()
    local dotfiles_aur=()

    if [[ -f "$PACKAGES_FILE" ]]; then
        # Filter packages by hardware (same as install does)
        local filtered_packages=$(filter_packages_by_hardware "$PACKAGES_FILE")
        while IFS= read -r pkg; do
            [[ -n "$pkg" && ! "$pkg" =~ ^# ]] && dotfiles_official+=("$pkg")
        done < "$filtered_packages"
        rm -f "$filtered_packages"
    fi

    if [[ -f "$AUR_PACKAGES_FILE" ]]; then
        while IFS= read -r pkg; do
            [[ -n "$pkg" && ! "$pkg" =~ ^# ]] && dotfiles_aur+=("$pkg")
        done < "$AUR_PACKAGES_FILE"
    fi

    # Find differences
    local missing_official=()
    local missing_aur=()
    local extra_official=()
    local extra_aur=()

    # Missing = in dotfiles but not installed (check ANY installation, not just explicit)
    for pkg in "${dotfiles_official[@]}"; do
        if [[ ! " ${installed_official[@]} " =~ " ${pkg} " ]]; then
            # Double-check if it's installed as a dependency
            if ! pacman -Q "$pkg" &>/dev/null; then
                missing_official+=("$pkg")
            fi
        fi
    done

    for pkg in "${dotfiles_aur[@]}"; do
        if [[ ! " ${installed_aur[@]} " =~ " ${pkg} " ]]; then
            # Double-check if it's installed as a dependency
            if ! pacman -Q "$pkg" &>/dev/null; then
                missing_aur+=("$pkg")
            fi
        fi
    done

    # Extra = installed but not in dotfiles
    for pkg in "${installed_official[@]}"; do
        if [[ ! " ${dotfiles_official[@]} " =~ " ${pkg} " ]]; then
            extra_official+=("$pkg")
        fi
    done

    for pkg in "${installed_aur[@]}"; do
        if [[ ! " ${dotfiles_aur[@]} " =~ " ${pkg} " ]]; then
            extra_aur+=("$pkg")
        fi
    done

    local total_missing=$((${#missing_official[@]} + ${#missing_aur[@]}))
    local total_extra=$((${#extra_official[@]} + ${#extra_aur[@]}))

    # Show status with formatted table
    echo
    log_info "Package Summary:"
    echo

    # Simple formatted table (gum table is for selection, not display)
    printf "  %-12s %10s %10s %10s\n" "Source" "Official" "AUR" "Total"
    printf "  %-12s %10s %10s %10s\n" "------------" "----------" "----------" "----------"
    printf "  %-12s %10d %10d %10d\n" "Dotfiles" "${#dotfiles_official[@]}" "${#dotfiles_aur[@]}" "$((${#dotfiles_official[@]} + ${#dotfiles_aur[@]}))"
    printf "  %-12s %10d %10d %10d\n" "Installed" "${#installed_official[@]}" "${#installed_aur[@]}" "$((${#installed_official[@]} + ${#installed_aur[@]}))"
    printf "  %-12s %10d %10d %10d\n" "Missing" "${#missing_official[@]}" "${#missing_aur[@]}" "$total_missing"
    printf "  %-12s %10d %10d %10d\n" "Extra" "${#extra_official[@]}" "${#extra_aur[@]}" "$total_extra"
    echo

    if [[ $total_missing -eq 0 && $total_extra -eq 0 ]]; then
        log_success "System and dotfiles are in perfect sync!"
        return 0
    fi

    # Show missing packages
    if [[ $total_missing -gt 0 ]]; then
        log_warning "Missing packages (in dotfiles, not installed): $total_missing"
        local all_missing=("${missing_official[@]}" "${missing_aur[@]}")
        printf '%s\n' "${all_missing[@]}" | sort | while read -r pkg; do
            printf '  - %s\n' "$pkg"
        done
        echo
    fi

    # Check if any "extra" packages are actually dependencies of dotfiles packages
    local extra_as_deps_official=()
    local extra_as_deps_aur=()
    local extra_not_deps=()
    
    # Build dotfiles map for dependency checking
    declare -A dotfiles_map
    for pkg in "${dotfiles_official[@]}" "${dotfiles_aur[@]}"; do
        dotfiles_map[$pkg]=1
    done
    
    # Check each extra package to see if it's a dependency
    for pkg in "${extra_official[@]}" "${extra_aur[@]}"; do
        local required_by=$(pacman -Qi "$pkg" 2>/dev/null | awk '/^Required By/ {for(i=4;i<=NF;i++) print $i}')
        local is_dependency=false
        
        if [[ -n "$required_by" ]]; then
            while IFS= read -r req; do
                if [[ -n "${dotfiles_map[$req]}" ]]; then
                    is_dependency=true
                    break
                fi
            done <<< "$required_by"
        fi
        
        if $is_dependency; then
            if pacman -Qm "$pkg" &>/dev/null; then
                extra_as_deps_aur+=("$pkg")
            else
                extra_as_deps_official+=("$pkg")
            fi
        else
            extra_not_deps+=("$pkg")
        fi
    done
    
    # Show extra packages, separating dependencies from truly extra
    if [[ $total_extra -gt 0 ]]; then
        if [[ $((${#extra_as_deps_official[@]} + ${#extra_as_deps_aur[@]})) -gt 0 ]]; then
            log_info "Dependencies detected (will be auto-added): $((${#extra_as_deps_official[@]} + ${#extra_as_deps_aur[@]}))"
            local all_deps=("${extra_as_deps_official[@]}" "${extra_as_deps_aur[@]}")
            printf '%s\n' "${all_deps[@]}" | sort | while read -r pkg; do
                printf '  - %s (dependency)\n' "$pkg"
            done
            echo
        fi
        
        if [[ ${#extra_not_deps[@]} -gt 0 ]]; then
            log_warning "Extra packages (installed, not in dotfiles): ${#extra_not_deps[@]}"
            printf '%s\n' "${extra_not_deps[@]}" | sort | while read -r pkg; do
                printf '  - %s\n' "$pkg"
            done
            echo
        fi
    fi

    # Check if any "missing" packages are actually installed as dependencies
    local deps_as_explicit=()
    for pkg in "${missing_official[@]}" "${missing_aur[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then
            deps_as_explicit+=("$pkg")
        fi
    done
    
    # Offer smart actions based on what's found
    local options=()

    # Always show "Install all from dotfiles" option
    options+=("Install all from dotfiles (reinstall everything)")

    if [[ ${#deps_as_explicit[@]} -gt 0 ]]; then
        options+=("Mark ${#deps_as_explicit[@]} dependency packages as explicit (already installed)")
    fi
    
    # Add option to auto-add dependencies if found
    if [[ $((${#extra_as_deps_official[@]} + ${#extra_as_deps_aur[@]})) -gt 0 ]]; then
        options+=("Add $((${#extra_as_deps_official[@]} + ${#extra_as_deps_aur[@]})) dependencies to dotfiles (auto-detect)")
    fi
    
    [[ $total_missing -gt 0 ]] && options+=("Install missing packages ($total_missing)")
    [[ $total_missing -gt 0 ]] && options+=("Remove missing from dotfiles ($total_missing)")
    [[ ${#extra_not_deps[@]} -gt 0 ]] && options+=("Add extra to dotfiles (${#extra_not_deps[@]})")
    [[ ${#extra_not_deps[@]} -gt 0 ]] && options+=("Remove extra from system (${#extra_not_deps[@]})")
    [[ ${#extra_not_deps[@]} -gt 0 ]] && options+=("Select which to keep/remove")
    [[ $total_missing -gt 0 && $total_extra -gt 0 ]] && options+=("Full sync (install + add)")

    local action=$(choose_option --header "What would you like to do?" "${options[@]}")
    [[ -z "$action" ]] && return 1  # ESC pressed

    case "$action" in
        "Install all from dotfiles"*)
            log_info "Installing all packages from dotfiles..."
            echo
            log_warning "This will install/reinstall ALL packages in your dotfiles"
            echo

            # Call the main install function which handles everything
            packages_install
            ;;

        "Mark"*"dependency packages as explicit"*)
            log_info "Marking ${#deps_as_explicit[@]} packages as explicitly installed..."
            echo
            printf '  - %s\n' "${deps_as_explicit[@]}"
            echo
            sudo pacman -D --asexplicit "${deps_as_explicit[@]}"
            log_success "Packages marked as explicit"
            ;;

        "Add"*"dependencies to dotfiles"*)
            log_info "Adding $((${#extra_as_deps_official[@]} + ${#extra_as_deps_aur[@]})) dependencies to dotfiles..."
            echo
            
            for pkg in "${extra_as_deps_official[@]}"; do
                echo "$pkg" >> "$PACKAGES_FILE"
            done
            for pkg in "${extra_as_deps_aur[@]}"; do
                echo "$pkg" >> "$AUR_PACKAGES_FILE"
            done
            
            sort -u "$PACKAGES_FILE" -o "$PACKAGES_FILE"
            sort -u "$AUR_PACKAGES_FILE" -o "$AUR_PACKAGES_FILE"
            
            log_success "Added $((${#extra_as_deps_official[@]} + ${#extra_as_deps_aur[@]})) dependencies to dotfiles"
            ;;

        "Install missing packages"*)
            log_info "Installing $total_missing packages..."
            echo
            
            # Prepare system (mirrors, multilib, database sync)
            packages_prepare
            
            # Install missing official packages
            if [[ ${#missing_official[@]} -gt 0 ]]; then
                log_info "Installing ${#missing_official[@]} official packages..."
                echo
                printf "1\nY\n" | sudo pacman -S --needed --noconfirm "${missing_official[@]}"
                echo
            fi
            
            # Install missing AUR packages
            if [[ ${#missing_aur[@]} -gt 0 ]]; then
                ensure_yay_installed
                log_info "Installing ${#missing_aur[@]} AUR packages..."
                echo
                printf "1\nY\n" | yay -S --needed --noconfirm --refresh --answerclean None --answerdiff None --removemake "${missing_aur[@]}"
                echo
            fi
            
            log_success "Installation complete"
            ;;

        "Remove missing from dotfiles"*)
            log_info "Removing $total_missing packages from dotfiles..."
            echo

            # Remove from packages/arch.package
            for pkg in "${missing_official[@]}"; do
                sed -i "/^${pkg}$/d" "$PACKAGES_FILE"
            done

            # Remove from packages/aur.package
            for pkg in "${missing_aur[@]}"; do
                sed -i "/^${pkg}$/d" "$AUR_PACKAGES_FILE"
            done

            log_success "Removed $total_missing packages from dotfiles"
            ;;

        "Add extra to dotfiles"*)
            for pkg in "${extra_not_deps[@]}"; do
                # Determine if it's AUR or official
                if pacman -Qm "$pkg" &>/dev/null; then
                    echo "$pkg" >> "$AUR_PACKAGES_FILE"
                else
                    echo "$pkg" >> "$PACKAGES_FILE"
                fi
            done
            sort -u "$PACKAGES_FILE" -o "$PACKAGES_FILE"
            sort -u "$AUR_PACKAGES_FILE" -o "$AUR_PACKAGES_FILE"
            log_success "Added ${#extra_not_deps[@]} packages to dotfiles"
            ;;

        "Remove extra from system"*)
            log_info "Checking which of ${#extra_not_deps[@]} packages can be safely removed..."
            echo
            local all_extra=("${extra_not_deps[@]}")
            
            # Filter out packages that are dependencies
            local safe_to_remove=()
            local blocked_packages=()
            
            for pkg in "${all_extra[@]}"; do
                local required_by=$(pacman -Qi "$pkg" 2>/dev/null | grep "Required By" | cut -d: -f2 | xargs)
                
                if [[ -z "$required_by" || "$required_by" == "None" ]]; then
                    safe_to_remove+=("$pkg")
                else
                    blocked_packages+=("$pkg (required by: $required_by)")
                fi
            done
            
            if [[ ${#blocked_packages[@]} -gt 0 ]]; then
                log_info "Packages blocked (required by other packages):"
                printf '  - %s\n' "${blocked_packages[@]}"
                echo
            fi
            
            if [[ ${#safe_to_remove[@]} -gt 0 ]]; then
                log_info "Removing ${#safe_to_remove[@]} packages:"
                printf '  - %s\n' "${safe_to_remove[@]}"
                echo
                
                sudo pacman -Rns "${safe_to_remove[@]}"
                log_success "Removed ${#safe_to_remove[@]} packages"
            else
                log_info "No packages can be safely removed (all are dependencies)"
            fi
            ;;

        "Select which to keep/remove"*)
            packages_clean_unlisted
            ;;

        "Full sync"*)
            log_info "Full sync: Installing missing + adding dependencies and extras to dotfiles..."
            echo
            
            # Install missing packages (same as "Install missing packages" option)
            if [[ $total_missing -gt 0 ]]; then
                packages_prepare
                
                if [[ ${#missing_official[@]} -gt 0 ]]; then
                    log_info "Installing ${#missing_official[@]} official packages..."
                    echo
                    printf "1\nY\n" | sudo pacman -S --needed --noconfirm "${missing_official[@]}"
                    echo
                fi
                
                if [[ ${#missing_aur[@]} -gt 0 ]]; then
                    ensure_yay_installed
                    log_info "Installing ${#missing_aur[@]} AUR packages..."
                    echo
                    printf "1\nY\n" | yay -S --needed --noconfirm --refresh --answerclean None --answerdiff None --removemake "${missing_aur[@]}"
                    echo
                fi
            fi
            
            # Add dependencies and extra packages to dotfiles
            echo
            log_info "Adding dependencies and extras to dotfiles..."
            for pkg in "${extra_as_deps_official[@]}"; do
                echo "$pkg" >> "$PACKAGES_FILE"
            done
            for pkg in "${extra_as_deps_aur[@]}"; do
                echo "$pkg" >> "$AUR_PACKAGES_FILE"
            done
            for pkg in "${extra_not_deps[@]}"; do
                if pacman -Qm "$pkg" &>/dev/null; then
                    echo "$pkg" >> "$AUR_PACKAGES_FILE"
                else
                    echo "$pkg" >> "$PACKAGES_FILE"
                fi
            done
            sort -u "$PACKAGES_FILE" -o "$PACKAGES_FILE"
            sort -u "$AUR_PACKAGES_FILE" -o "$AUR_PACKAGES_FILE"
            log_success "Full sync complete!"
            ;;
    esac
}

# Clean unlisted packages (remove packages not in dotfiles)
packages_clean_unlisted() {
    log_section "Cleaning Unlisted Packages"

    log_info "Finding packages not in dotfiles..."

    # Read dotfiles packages
    local dotfiles_official=()
    local dotfiles_aur=()

    if [[ -f "$PACKAGES_FILE" ]]; then
        while IFS= read -r pkg; do
            [[ -n "$pkg" && ! "$pkg" =~ ^# ]] && dotfiles_official+=("$pkg")
        done < "$PACKAGES_FILE"
    fi

    if [[ -f "$AUR_PACKAGES_FILE" ]]; then
        while IFS= read -r pkg; do
            [[ -n "$pkg" && ! "$pkg" =~ ^# ]] && dotfiles_aur+=("$pkg")
        done < "$AUR_PACKAGES_FILE"
    fi

    # Get installed packages
    local installed_official=()
    while IFS= read -r pkg; do
        installed_official+=("$pkg")
    done < <(pacman -Qeq | grep -vf <(pacman -Qmq))

    local installed_aur=()
    while IFS= read -r pkg; do
        installed_aur+=("$pkg")
    done < <(pacman -Qmq)

    # Find unlisted packages
    local unlisted_official=()
    local unlisted_aur=()

    for pkg in "${installed_official[@]}"; do
        if [[ ! " ${dotfiles_official[@]} " =~ " ${pkg} " ]]; then
            unlisted_official+=("$pkg")
        fi
    done

    for pkg in "${installed_aur[@]}"; do
        if [[ ! " ${dotfiles_aur[@]} " =~ " ${pkg} " ]]; then
            unlisted_aur+=("$pkg")
        fi
    done

    local total_unlisted=$((${#unlisted_official[@]} + ${#unlisted_aur[@]}))

    if [[ $total_unlisted -eq 0 ]]; then
        log_success "All installed packages are in dotfiles"
        return 0
    fi

    echo
    log_warning "Found $total_unlisted packages not in dotfiles:"
    echo

    if [[ ${#unlisted_official[@]} -gt 0 ]]; then
        log_info "Official packages (${#unlisted_official[@]}):"
        for pkg in "${unlisted_official[@]}"; do
            printf '  - %s\n' "$pkg"
        done
        echo
    fi

    if [[ ${#unlisted_aur[@]} -gt 0 ]]; then
        log_info "AUR packages (${#unlisted_aur[@]}):"
        for pkg in "${unlisted_aur[@]}"; do
            printf '  - %s\n' "$pkg"
        done
        echo
    fi

    # Interactive selection
    local action=$(choose_option --header "What would you like to do?" \
            "Select packages to keep (rest will be removed)" \
            "Add all to dotfiles" \
            "Remove all unlisted packages" \
            "Cancel")

        case "$action" in
            "Select packages to keep (rest will be removed)")
                local all_unlisted=()
                for pkg in "${unlisted_official[@]}"; do
                    all_unlisted+=("$pkg (official)")
                done
                for pkg in "${unlisted_aur[@]}"; do
                    all_unlisted+=("$pkg (aur)")
                done

                # Use filter for search if many packages, otherwise multi-select
                local selected
                if [[ ${#all_unlisted[@]} -gt 20 ]]; then
                    log_info "Large list detected. Use fuzzy search to filter packages to KEEP:"
                    echo
                    selected=$(printf '%s\n' "${all_unlisted[@]}" | gum filter --no-limit --placeholder "Search packages to keep (Tab to select, Enter to confirm)...")
                else
                    selected=$(printf '%s\n' "${all_unlisted[@]}" | gum choose --no-limit --header "Select packages to KEEP (unselected will be removed):" --no-show-help)
                fi

                # Parse selected packages
                local keep_packages=()
                while IFS= read -r line; do
                    [[ -n "$line" ]] && keep_packages+=("${line% (*}")
                done <<< "$selected"

                # Build remove list
                local to_remove=()
                for pkg in "${unlisted_official[@]}" "${unlisted_aur[@]}"; do
                    if [[ ! " ${keep_packages[@]} " =~ " ${pkg} " ]]; then
                        to_remove+=("$pkg")
                    fi
                done

                if [[ ${#to_remove[@]} -eq 0 ]]; then
                    log_info "No packages selected for removal"
                    return 0
                fi

                # Filter out packages that are dependencies
                local safe_to_remove=()
                local blocked_packages=()
                
                for pkg in "${to_remove[@]}"; do
                    local required_by=$(pacman -Qi "$pkg" 2>/dev/null | grep "Required By" | cut -d: -f2 | xargs)
                    
                    if [[ -z "$required_by" || "$required_by" == "None" ]]; then
                        safe_to_remove+=("$pkg")
                    else
                        blocked_packages+=("$pkg (required by: $required_by)")
                    fi
                done
                
                echo
                
                if [[ ${#blocked_packages[@]} -gt 0 ]]; then
                    log_info "Packages blocked (required by other packages):"
                    printf '  - %s\n' "${blocked_packages[@]}"
                    echo
                fi
                
                if [[ ${#safe_to_remove[@]} -gt 0 ]]; then
                    log_warning "Will remove ${#safe_to_remove[@]} packages:"
                    printf '  - %s\n' "${safe_to_remove[@]}"
                    echo

                    sudo pacman -Rns --noconfirm "${safe_to_remove[@]}"
                    log_success "Removed ${#safe_to_remove[@]} packages"
                else
                    log_info "No packages can be safely removed (all are dependencies)"
                fi
                ;;

            "Add all to dotfiles")
                for pkg in "${unlisted_official[@]}"; do
                    echo "$pkg" >> "$PACKAGES_FILE"
                done
                for pkg in "${unlisted_aur[@]}"; do
                    echo "$pkg" >> "$AUR_PACKAGES_FILE"
                done

                # Sort files
                sort -u "$PACKAGES_FILE" -o "$PACKAGES_FILE"
                sort -u "$AUR_PACKAGES_FILE" -o "$AUR_PACKAGES_FILE"

                log_success "Added $total_unlisted packages to dotfiles"
                ;;

            "Remove all unlisted packages")
                echo
                log_warning "Checking which of $total_unlisted packages can be safely removed..."
                echo

                local all_to_remove=("${unlisted_official[@]}" "${unlisted_aur[@]}")
                
                # Filter out packages that are dependencies
                local safe_to_remove=()
                local blocked_packages=()
                
                for pkg in "${all_to_remove[@]}"; do
                    local required_by=$(pacman -Qi "$pkg" 2>/dev/null | grep "Required By" | cut -d: -f2 | xargs)
                    
                    if [[ -z "$required_by" || "$required_by" == "None" ]]; then
                        safe_to_remove+=("$pkg")
                    else
                        blocked_packages+=("$pkg (required by: $required_by)")
                    fi
                done
                
                if [[ ${#blocked_packages[@]} -gt 0 ]]; then
                    log_info "Packages blocked (required by other packages):"
                    printf '  - %s\n' "${blocked_packages[@]}"
                    echo
                fi
                
                if [[ ${#safe_to_remove[@]} -gt 0 ]]; then
                    log_info "Removing ${#safe_to_remove[@]} packages:"
                    printf '  - %s\n' "${safe_to_remove[@]}"
                    echo
                    
                    sudo pacman -Rns --noconfirm "${safe_to_remove[@]}"
                    log_success "Removed ${#safe_to_remove[@]} packages"
                else
                    log_info "No packages can be safely removed (all are dependencies)"
                fi
                ;;

            *)
                log_info "Cancelled"
                ;;
        esac
}
