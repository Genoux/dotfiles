#\!/bin/bash
# Interactive package management and cleanup
# Requires: gum (charmbracelet/gum)

# Comprehensive package management (handle all sync scenarios)
packages_manage() {
    log_section "Package Management"

    # Get all installed packages in one call for O(1) lookups
    local -A all_installed=()
    while IFS= read -r pkg; do
        all_installed["$pkg"]=1
    done < <(pacman -Qq 2>/dev/null)

    # Get AUR package list for categorization
    local -A aur_packages_set=()
    while IFS= read -r pkg; do
        aur_packages_set["$pkg"]=1
    done < <(pacman -Qmq 2>/dev/null)

    # Build arrays and hash maps for installed packages
    local installed_official=()
    local installed_aur=()
    local -A installed_official_map=()
    local -A installed_aur_map=()

    while IFS= read -r pkg; do
        if [[ -v aur_packages_set["$pkg"] ]]; then
            installed_aur+=("$pkg")
            installed_aur_map["$pkg"]=1
        else
            installed_official+=("$pkg")
            installed_official_map["$pkg"]=1
        fi
    done < <(pacman -Qeq 2>/dev/null)

    # Read dotfiles packages (with hardware filtering)
    local dotfiles_official=()
    local dotfiles_aur=()
    local -A dotfiles_official_map=()
    local -A dotfiles_aur_map=()

    if [[ -f "$PACKAGES_FILE" ]]; then
        while IFS= read -r pkg; do
            if [[ -n "$pkg" && ! "$pkg" =~ ^# ]]; then
                dotfiles_official+=("$pkg")
                dotfiles_official_map["$pkg"]=1
            fi
        done < "$PACKAGES_FILE"
    fi

    if [[ -f "$AUR_PACKAGES_FILE" ]]; then
        while IFS= read -r pkg; do
            if [[ -n "$pkg" && ! "$pkg" =~ ^# ]]; then
                dotfiles_aur+=("$pkg")
                dotfiles_aur_map["$pkg"]=1
            fi
        done < "$AUR_PACKAGES_FILE"
    fi

    # Read hardware packages (managed separately, should not show as "extra")
    if [[ -d "$DOTFILES_DIR/packages/hardware" ]]; then
        for hw_file in "$DOTFILES_DIR/packages/hardware"/*.package; do
            [[ -f "$hw_file" ]] || continue
            while IFS= read -r pkg; do
                if [[ -n "$pkg" && ! "$pkg" =~ ^# ]]; then
                    # Check if it's an AUR package to categorize correctly
                    if [[ -v aur_packages_set["$pkg"] ]]; then
                        dotfiles_aur_map["$pkg"]=1
                    else
                        dotfiles_official_map["$pkg"]=1
                    fi
                fi
            done < "$hw_file"
        done
    fi

    # Find differences using hash maps for O(1) lookups
    local missing_official=()
    local missing_aur=()
    local extra_official=()
    local extra_aur=()

    for pkg in "${dotfiles_official[@]}"; do
        if [[ ! -v all_installed["$pkg"] ]]; then
            missing_official+=("$pkg")
        fi
    done

    for pkg in "${dotfiles_aur[@]}"; do
        if [[ ! -v all_installed["$pkg"] ]]; then
            missing_aur+=("$pkg")
        fi
    done

    for pkg in "${installed_official[@]}"; do
        if [[ ! -v dotfiles_official_map["$pkg"] ]]; then
            extra_official+=("$pkg")
        fi
    done

    for pkg in "${installed_aur[@]}"; do
        if [[ ! -v dotfiles_aur_map["$pkg"] ]]; then
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
    printf "%-12s %10s %10s %10s\n" "Source" "Official" "AUR" "Total"
    printf "%-12s %10s %10s %10s\n" "------------" "----------" "----------" "----------"
    printf "%-12s %10d %10d %10d\n" "Dotfiles" "${#dotfiles_official[@]}" "${#dotfiles_aur[@]}" "$((${#dotfiles_official[@]} + ${#dotfiles_aur[@]}))"
    printf "%-12s %10d %10d %10d\n" "Installed" "${#installed_official[@]}" "${#installed_aur[@]}" "$((${#installed_official[@]} + ${#installed_aur[@]}))"
    printf "%-12s %10d %10d %10d\n" "Missing" "${#missing_official[@]}" "${#missing_aur[@]}" "$total_missing"
    printf "%-12s %10d %10d %10d\n" "Extra" "${#extra_official[@]}" "${#extra_aur[@]}" "$total_extra"
    echo

    # Show missing packages
    if [[ $total_missing -gt 0 ]]; then
        log_warning "Missing packages (in dotfiles, not installed): $total_missing"
        local all_missing=("${missing_official[@]}" "${missing_aur[@]}")
        printf '%s\n' "${all_missing[@]}" | sort | while read -r pkg; do
            printf '  - %s\n' "$pkg"
        done
        echo
    fi

    # Show extra packages (all treated the same - manual selection will handle them)
    if [[ $total_extra -gt 0 ]]; then
        log_warning "Extra packages (installed, not in dotfiles): $total_extra"
        local all_extra=("${extra_official[@]}" "${extra_aur[@]}")
        printf '%s\n' "${all_extra[@]}" | sort | while read -r pkg; do
            printf '  - %s\n' "$pkg"
        done
        echo
    fi
    
    # Offer smart actions based on what's found
    local options=()

    # Always show "Install all from dotfiles" option
    options+=("Install all from dotfiles (reinstall everything)")

    # Comprehensive manual selection option - show all out-of-sync packages
    if [[ $total_missing -gt 0 || $total_extra -gt 0 ]]; then
        local total_to_manage=$((total_missing + total_extra))
        options+=("Select packages manually ($total_to_manage to review)")
    fi

    local action=$(choose_option --header "What would you like to do?" "${options[@]}")
    if [[ -z "$action" ]]; then
        SKIP_PAUSE=1
        return 1  # ESC pressed
    fi

    clear

    case "$action" in
        "Install all from dotfiles"*)
            log_info "Installing all packages from dotfiles..."
            echo
            log_warning "This will install/reinstall ALL packages in your dotfiles"
            echo

            # Call the main install function which handles everything
            packages_install
            ;;

        "Select packages manually"*)
            packages_select_manually
            ;;
    esac
}

# Select packages manually (comprehensive interface for all package operations)
packages_select_manually() {
    log_section "Select Packages Manually"

    # Phase 1: Collect ONLY out-of-sync packages (missing + extra)
    declare -A all_packages  # pkg_name -> type
    declare -A is_installed  # pkg_name -> 1 if installed

    # Add missing packages (in dotfiles but not installed)
    for pkg in "${missing_official[@]}"; do
        all_packages["$pkg"]="official"
    done

    for pkg in "${missing_aur[@]}"; do
        all_packages["$pkg"]="aur"
    done

    # Add extra packages (installed but not in dotfiles)
    for pkg in "${extra_official[@]}" "${extra_aur[@]}"; do
        if [[ ! -v all_packages["$pkg"] ]]; then
            # Determine type
            if pacman -Qm "$pkg" &>/dev/null; then
                all_packages["$pkg"]="aur"
            else
                all_packages["$pkg"]="official"
            fi
            is_installed["$pkg"]=1
        fi
    done

    # Phase 2: Build display list and pre-select installed packages
    local display_list=()
    local preselected=()

    for pkg in "${!all_packages[@]}"; do
        local type="${all_packages[$pkg]}"
        local display_item="$pkg ($type)"
        display_list+=("$display_item")

        # Pre-select if currently installed
        if [[ -v is_installed["$pkg"] ]]; then
            preselected+=("$display_item")
        fi
    done

    # Sort display list
    IFS=$'\n' display_list=($(sort <<<"${display_list[*]}"))
    IFS=$'\n' preselected=($(sort <<<"${preselected[*]}"))

    # Phase 3: Present selection UI
    local total_items=${#display_list[@]}
    local selected_output
    local selection_status

    if [[ $total_items -ge 20 ]]; then
        # Use filter for large lists
        selected_output=$(printf '%s\n' "${display_list[@]}" | \
            filter_search "Select packages to keep...")
        selection_status=$?
    else
        # Use choose for small lists - build pre-selection string with actual newlines
        selected_output=$(printf '%s\n' "${display_list[@]}" | \
            gum choose --no-limit \
            --header "Select packages to keep (✓=install/keep, ✗=remove):" \
            $(printf -- "--selected=%s\n" "${preselected[@]}"))
        selection_status=$?
    fi

    # Handle ESC cancellation - return directly to menu without any message
    if [[ $selection_status -ne 0 ]]; then
        SKIP_PAUSE=1
        return 0
    fi

    # Phase 4: Parse selection and determine actions
    declare -A selected_map
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        # Extract package name (before parentheses)
        local pkg_name="${line%% (*}"
        selected_map["$pkg_name"]=1
    done <<< "$selected_output"

    # Determine actions for each package
    local to_install_official=()
    local to_install_aur=()
    local to_remove_official=()
    local to_remove_aur=()
    local to_add_dotfiles_official=()
    local to_add_dotfiles_aur=()
    local to_remove_dotfiles_official=()
    local to_remove_dotfiles_aur=()

    for pkg in "${!all_packages[@]}"; do
        local type="${all_packages[$pkg]}"
        local selected=$([[ -v selected_map["$pkg"] ]] && echo "yes" || echo "no")
        local installed=$([[ -v is_installed["$pkg"] ]] && echo "yes" || echo "no")
        local in_dotfiles=$([[ -v dotfiles_official_map["$pkg"] || -v dotfiles_aur_map["$pkg"] ]] && echo "yes" || echo "no")

        if [[ "$selected" == "yes" ]]; then
            # CHECKED: Install + add to dotfiles
            if [[ "$installed" == "no" ]]; then
                [[ "$type" == "aur" ]] && to_install_aur+=("$pkg") || to_install_official+=("$pkg")
            fi
            if [[ "$in_dotfiles" == "no" ]]; then
                [[ "$type" == "aur" ]] && to_add_dotfiles_aur+=("$pkg") || to_add_dotfiles_official+=("$pkg")
            fi
        else
            # UNCHECKED: Uninstall + remove from dotfiles
            if [[ "$installed" == "yes" ]]; then
                [[ "$type" == "aur" ]] && to_remove_aur+=("$pkg") || to_remove_official+=("$pkg")
            fi
            if [[ "$in_dotfiles" == "yes" ]]; then
                [[ "$type" == "aur" ]] && to_remove_dotfiles_aur+=("$pkg") || to_remove_dotfiles_official+=("$pkg")
            fi
        fi
    done

    # Phase 5: Dependency validation for removal
    local safe_to_remove_official=()
    local safe_to_remove_aur=()
    local blocked_removals=()

    for pkg in "${to_remove_official[@]}" "${to_remove_aur[@]}"; do
        local required_by=$(pacman -Qi "$pkg" 2>/dev/null | grep "Required By" | cut -d: -f2 | xargs)

        if [[ -z "$required_by" || "$required_by" == "None" ]]; then
            # Safe to remove - no dependencies
            if [[ "${all_packages[$pkg]}" == "aur" ]]; then
                safe_to_remove_aur+=("$pkg")
            else
                safe_to_remove_official+=("$pkg")
            fi
        else
            # Has dependencies - check if safe to remove
            local is_blocked=false
            local blocker=""

            for req in $required_by; do
                # Block if requirer is:
                # 1. Selected (user wants to keep it), OR
                # 2. Not in out-of-sync list (already synced, should stay)
                if [[ -v selected_map["$req"] ]] || [[ ! -v all_packages["$req"] ]]; then
                    is_blocked=true
                    blocker="$req"
                    break
                fi
            done

            if [[ "$is_blocked" == "true" ]]; then
                blocked_removals+=("$pkg (required by: $blocker)")
            else
                # All requirers are also being removed, safe
                if [[ "${all_packages[$pkg]}" == "aur" ]]; then
                    safe_to_remove_aur+=("$pkg")
                else
                    safe_to_remove_official+=("$pkg")
                fi
            fi
        fi
    done

    # Phase 6: Show confirmation summary
    clear
    log_section "Confirmation Summary"
    echo

    # Count totals
    local total_install=$((${#to_install_official[@]} + ${#to_install_aur[@]}))
    local total_remove=$((${#safe_to_remove_official[@]} + ${#safe_to_remove_aur[@]}))
    local total_add_df=$((${#to_add_dotfiles_official[@]} + ${#to_add_dotfiles_aur[@]}))
    local total_remove_df=$((${#to_remove_dotfiles_official[@]} + ${#to_remove_dotfiles_aur[@]}))

    # Nothing to do?
    if [[ $total_install -eq 0 && $total_remove -eq 0 && $total_add_df -eq 0 && $total_remove_df -eq 0 ]]; then
        log_success "No changes needed"
        return 0
    fi

    # Show packages to install
    if [[ $total_install -gt 0 ]]; then
        log_info "Install ($total_install):"
        local all_to_install=("${to_install_official[@]}" "${to_install_aur[@]}")
        printf '  %s\n' "${all_to_install[@]}" | sort
        echo
    fi

    # Show packages to remove
    if [[ $total_remove -gt 0 ]]; then
        log_info "Remove ($total_remove):"
        local all_to_remove=("${safe_to_remove_official[@]}" "${safe_to_remove_aur[@]}")
        printf '  %s\n' "${all_to_remove[@]}" | sort
        echo
    fi

    # Show packages being added to dotfiles
    if [[ $total_add_df -gt 0 ]]; then
        log_info "Add to dotfiles ($total_add_df):"
        local all_add_df=("${to_add_dotfiles_official[@]}" "${to_add_dotfiles_aur[@]}")
        printf '  %s\n' "${all_add_df[@]}" | sort
        echo
    fi

    # Show packages being removed from dotfiles
    if [[ $total_remove_df -gt 0 ]]; then
        log_info "Remove from dotfiles ($total_remove_df):"
        local all_remove_df=("${to_remove_dotfiles_official[@]}" "${to_remove_dotfiles_aur[@]}")
        printf '  %s\n' "${all_remove_df[@]}" | sort
        echo
    fi

    # Show blocked removals if any
    if [[ ${#blocked_removals[@]} -gt 0 ]]; then
        log_warning "Cannot remove (${#blocked_removals[@]}):"
        printf '  %s\n' "${blocked_removals[@]}"
        echo
    fi

    # Confirm before applying changes
    echo
    if ! gum_confirm "Apply these changes?"; then
        SKIP_PAUSE=1
        return 0
    fi
    echo

    # Phase 7: Execute changes
    clear
    log_section "Applying Changes"
    echo

    # Remove packages first
    if [[ $total_remove -gt 0 ]]; then
        log_info "Removing $total_remove packages..."
        echo

        local all_to_remove=("${safe_to_remove_official[@]}" "${safe_to_remove_aur[@]}")
        if sudo pacman -Rns --noconfirm "${all_to_remove[@]}"; then
            log_success "Removed $total_remove packages"
        else
            log_warning "Some packages failed to remove, continuing..."
        fi
        echo
    fi

    # Install packages
    if [[ $total_install -gt 0 ]]; then
        packages_prepare

        if [[ ${#to_install_official[@]} -gt 0 ]]; then
            log_info "Installing ${#to_install_official[@]} official packages..."
            echo
            sudo pacman -S --needed --noconfirm "${to_install_official[@]}"
            echo
        fi

        if [[ ${#to_install_aur[@]} -gt 0 ]]; then
            ensure_yay_installed
            log_info "Installing ${#to_install_aur[@]} AUR packages..."
            echo
            yay -S --needed --noconfirm "${to_install_aur[@]}"
            echo
        fi
    fi

    # Update dotfiles
    if [[ $total_add_df -gt 0 || $total_remove_df -gt 0 ]]; then
        log_info "Updating dotfiles..."

        # Backup files
        cp "$PACKAGES_FILE" "$PACKAGES_FILE.backup"
        cp "$AUR_PACKAGES_FILE" "$AUR_PACKAGES_FILE.backup"

        # Remove from dotfiles
        for pkg in "${to_remove_dotfiles_official[@]}"; do
            sed -i "/^${pkg}$/d" "$PACKAGES_FILE"
        done
        for pkg in "${to_remove_dotfiles_aur[@]}"; do
            sed -i "/^${pkg}$/d" "$AUR_PACKAGES_FILE"
        done

        # Add to dotfiles
        for pkg in "${to_add_dotfiles_official[@]}"; do
            echo "$pkg" >> "$PACKAGES_FILE"
        done
        for pkg in "${to_add_dotfiles_aur[@]}"; do
            echo "$pkg" >> "$AUR_PACKAGES_FILE"
        done

        # Sort and deduplicate
        sort -u "$PACKAGES_FILE" -o "$PACKAGES_FILE"
        sort -u "$AUR_PACKAGES_FILE" -o "$AUR_PACKAGES_FILE"

        # Verify changes
        if [[ -s "$PACKAGES_FILE" && -s "$AUR_PACKAGES_FILE" ]]; then
            rm -f "$PACKAGES_FILE.backup" "$AUR_PACKAGES_FILE.backup"
            log_success "Dotfiles updated"
        else
            log_error "Dotfiles update failed, restoring backups"
            mv "$PACKAGES_FILE.backup" "$PACKAGES_FILE"
            mv "$AUR_PACKAGES_FILE.backup" "$AUR_PACKAGES_FILE"
        fi
        echo
    fi

    log_success "Manual selection complete!"
}
