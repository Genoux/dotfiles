#!/bin/bash
# Package management operations

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Package file locations
PACKAGES_FILE="$DOTFILES_DIR/packages.txt"
AUR_PACKAGES_FILE="$DOTFILES_DIR/aur-packages.txt"

# Prepare system for package installation
packages_prepare() {
    log_section "Preparing System"

    # Check if mirrors need updating (older than 7 days)
    local mirrorlist="/etc/pacman.d/mirrorlist"
    local needs_update=false

    if [[ -f "$mirrorlist" ]]; then
        local mirror_age=$(($(date +%s) - $(stat -c %Y "$mirrorlist")))
        local seven_days=$((7 * 24 * 60 * 60))

        if [[ $mirror_age -gt $seven_days ]]; then
            needs_update=true
            log_info "Mirror list is older than 7 days"
        else
            log_success "Mirror list is recent (updated $(date -d @$(stat -c %Y "$mirrorlist") '+%Y-%m-%d'))"
        fi
    else
        needs_update=true
    fi

    if $needs_update; then
        log_info "Updating pacman mirrors..."
        echo

        if ! command -v reflector &>/dev/null; then
            log_info "Installing reflector for mirror management..."
            sudo pacman -S --needed --noconfirm reflector
            echo
        fi

        # Backup existing mirrorlist
        sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

        log_info "Ranking mirrors by speed..."
        if ! sudo reflector \
            --country US \
            --age 6 \
            --protocol https \
            --sort rate \
            --fastest 10 \
            --connection-timeout 3 \
            --download-timeout 5 \
            --save /etc/pacman.d/mirrorlist.new; then
            log_error "Reflector failed, keeping existing mirrors"
            sudo rm -f /etc/pacman.d/mirrorlist.new
        elif [[ ! -s /etc/pacman.d/mirrorlist.new ]]; then
            log_error "Generated mirrorlist is empty, restoring backup"
            sudo rm -f /etc/pacman.d/mirrorlist.new
        else
            # Atomic move
            sudo mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist
            echo
            log_success "Mirrors updated and ranked"
        fi
    fi
    echo

    # Sync package databases
    log_info "Synchronizing package databases..."
    sudo pacman -Sy --noconfirm
    echo
    log_success "Package databases synchronized"
    echo
}

# Clean packages not in dotfiles lists
packages_clean() {
    log_section "Cleaning Packages"

    # Check if package files exist
    if [[ ! -f "$PACKAGES_FILE" ]] || [[ ! -f "$AUR_PACKAGES_FILE" ]]; then
        log_warning "Package lists not found, skipping clean"
        return
    fi

    # Read desired packages
    local desired_official=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^#.*$ ]] && continue
        desired_official+=("$pkg")
    done < "$PACKAGES_FILE"

    local desired_aur=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^#.*$ ]] && continue
        desired_aur+=("$pkg")
    done < "$AUR_PACKAGES_FILE"

    # Get currently installed explicitly installed packages
    local installed_official=()
    while IFS= read -r pkg; do
        installed_official+=("$pkg")
    done < <(pacman -Qeq | grep -vf <(pacman -Qmq))

    local installed_aur=()
    while IFS= read -r pkg; do
        installed_aur+=("$pkg")
    done < <(pacman -Qmq)

    # Find packages to remove
    local to_remove=()

    for pkg in "${installed_official[@]}"; do
        if [[ ! " ${desired_official[@]} " =~ " ${pkg} " ]]; then
            to_remove+=("$pkg")
        fi
    done

    for pkg in "${installed_aur[@]}"; do
        if [[ ! " ${desired_aur[@]} " =~ " ${pkg} " ]]; then
            to_remove+=("$pkg")
        fi
    done

    if [[ ${#to_remove[@]} -gt 0 ]]; then
        log_warning "Found ${#to_remove[@]} packages not in your dotfiles lists"
        echo
        log_info "Packages to remove:"
        printf '  - %s\n' "${to_remove[@]}"
        echo

        log_info "Removing packages..."
        sudo pacman -Rns --noconfirm "${to_remove[@]}"
        echo
        log_success "Packages removed"
    else
        log_success "No extra packages found"
    fi

    echo
}

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
        fatal_error "packages.txt not found in $DOTFILES_DIR"
    fi

    if [[ ! -f "$AUR_PACKAGES_FILE" ]]; then
        fatal_error "aur-packages.txt not found in $DOTFILES_DIR"
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

    # Just install packages from lists - no checking
    # For auditing system vs dotfiles, use package_audit function instead

    # Find missing official packages
    local missing_official=()
    for pkg in "${packages[@]}"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            missing_official+=("$pkg")
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
        sudo pacman -S --needed --noconfirm "${missing_official[@]}"
        echo
        log_success "Official packages installed"
    else
        log_success "All official packages already installed"
    fi
    
    echo
    
    # Ensure yay is installed for AUR packages
    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        if ! command -v yay &>/dev/null; then
            log_info "Installing yay (AUR helper)..."
            echo
            log_info "Installing base-devel and git..."
            sudo pacman -S --needed base-devel git
            echo
            log_info "Cloning yay repository..."
            cd /tmp
            rm -rf yay
            git clone --depth=1 --progress https://aur.archlinux.org/yay.git
            cd yay
            echo
            log_info "Building yay from source..."
            makepkg -si --noconfirm
            cd -
            echo
            log_success "yay installed"
            echo
        fi
        
        # Find missing AUR packages
        local missing_aur=()
        for pkg in "${aur_packages[@]}"; do
            if ! pacman -Q "$pkg" &>/dev/null; then
                missing_aur+=("$pkg")
            fi
        done
        
        # Install missing AUR packages
        if [[ ${#missing_aur[@]} -gt 0 ]]; then
            log_info "Installing ${#missing_aur[@]} AUR packages..."
            echo
            log_info "Packages to install: ${missing_aur[*]}"
            echo
            log_info "Installing AUR packages..."
            echo
            # Always non-interactive
            yay -S --needed --noconfirm --answerclean None --answerdiff None --removemake "${missing_aur[@]}"
            echo
            log_success "AUR packages installed"
        else
            log_success "All AUR packages already installed"
        fi
    fi
    
    echo
    log_success "Package installation complete"
}

# Sync package lists from system
packages_sync() {
    log_section "Syncing Package Lists"
    
    log_info "Scanning installed packages..."
    
    # Get all AUR packages first
    local aur_packages_temp=$(mktemp)
    pacman -Qm | awk '{print $1}' | sort > "$aur_packages_temp"
    
    # Create pattern for grep
    local aur_pattern=""
    if [[ -s "$aur_packages_temp" ]]; then
        aur_pattern=$(sed 's/[[\.*^$()+?{|]/\\&/g' "$aur_packages_temp" | paste -sd'|')
    fi
    
    # Get explicitly installed official packages (excluding AUR)
    local official_temp=$(mktemp)
    if [[ -n "$aur_pattern" ]]; then
        pacman -Qe | grep -vE "^($aur_pattern) " | awk '{print $1}' | sort > "$official_temp"
    else
        pacman -Qe | awk '{print $1}' | sort > "$official_temp"
    fi
    
    # Show changes
    local official_changes=false
    local aur_changes=false
    
    if [[ -f "$PACKAGES_FILE" ]]; then
        if ! diff -q "$official_temp" "$PACKAGES_FILE" &>/dev/null; then
            official_changes=true
            log_info "Changes detected in official packages:"
            diff --color=auto "$PACKAGES_FILE" "$official_temp" | grep "^[<>]" || true
        fi
    else
        official_changes=true
    fi
    
    if [[ -f "$AUR_PACKAGES_FILE" ]]; then
        if ! diff -q "$aur_packages_temp" "$AUR_PACKAGES_FILE" &>/dev/null; then
            aur_changes=true
            log_info "Changes detected in AUR packages:"
            diff --color=auto "$AUR_PACKAGES_FILE" "$aur_packages_temp" | grep "^[<>]" || true
        fi
    else
        aur_changes=true
    fi
    
    echo
    
    # Update files if changes detected
    if $official_changes || $aur_changes; then
        cp "$official_temp" "$PACKAGES_FILE"
        cp "$aur_packages_temp" "$AUR_PACKAGES_FILE"

        log_success "Package lists updated"
        show_info "Official packages" "$(wc -l < "$PACKAGES_FILE")"
        show_info "AUR packages" "$(wc -l < "$AUR_PACKAGES_FILE")"
    else
        log_success "Package lists are already up to date"
    fi
    
    # Cleanup
    rm -f "$official_temp" "$aur_packages_temp"
}

# Comprehensive package management (handle all sync scenarios)
packages_manage() {
    log_section "Package Management"

    log_info "Analyzing packages..."

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

    # Find differences
    local missing_official=()
    local missing_aur=()
    local extra_official=()
    local extra_aur=()

    # Missing = in dotfiles but not installed
    for pkg in "${dotfiles_official[@]}"; do
        if [[ ! " ${installed_official[@]} " =~ " ${pkg} " ]]; then
            missing_official+=("$pkg")
        fi
    done

    for pkg in "${dotfiles_aur[@]}"; do
        if [[ ! " ${installed_aur[@]} " =~ " ${pkg} " ]]; then
            missing_aur+=("$pkg")
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

    # Show status
    echo
    log_info "Status:"
    show_info "  In dotfiles" "$((${#dotfiles_official[@]} + ${#dotfiles_aur[@]})) packages"
    show_info "  Installed" "$((${#installed_official[@]} + ${#installed_aur[@]})) packages"
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

    # Show extra packages
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

    [[ $total_missing -gt 0 ]] && options+=("Install missing packages ($total_missing)")
    [[ $total_extra -gt 0 ]] && options+=("Add extra to dotfiles ($total_extra)")
    [[ $total_extra -gt 0 ]] && options+=("Remove extra from system ($total_extra)")
    [[ $total_extra -gt 0 ]] && options+=("Select which to keep/remove")
    [[ $total_missing -gt 0 && $total_extra -gt 0 ]] && options+=("Full sync (install + add)")

    local action=$(gum choose --header "What would you like to do?" "${options[@]}")
    [[ -z "$action" ]] && return  # ESC pressed

    case "$action" in
        "Install missing packages"*)
            packages_install
            ;;

        "Add extra to dotfiles"*)
            for pkg in "${extra_official[@]}"; do
                echo "$pkg" >> "$PACKAGES_FILE"
            done
            for pkg in "${extra_aur[@]}"; do
                echo "$pkg" >> "$AUR_PACKAGES_FILE"
            done
            sort -u "$PACKAGES_FILE" -o "$PACKAGES_FILE"
            sort -u "$AUR_PACKAGES_FILE" -o "$AUR_PACKAGES_FILE"
            log_success "Added $total_extra packages to dotfiles"
            ;;

        "Remove extra from system"*)
            log_info "Removing $total_extra packages..."
            echo
            local all_extra=("${extra_official[@]}" "${extra_aur[@]}")
            sudo pacman -Rns "${all_extra[@]}"
            log_success "Removed $total_extra packages"
            ;;

        "Select which to keep/remove"*)
            packages_clean_unlisted
            ;;

        "Full sync"*)
            log_info "Full sync: Installing missing + adding extras to dotfiles..."
            echo
            packages_install
            echo
            for pkg in "${extra_official[@]}"; do
                echo "$pkg" >> "$PACKAGES_FILE"
            done
            for pkg in "${extra_aur[@]}"; do
                echo "$pkg" >> "$AUR_PACKAGES_FILE"
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
    local action=$(gum choose --header "What would you like to do?" \
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

                local selected=$(printf '%s\n' "${all_unlisted[@]}" | gum choose --no-limit --header "Select packages to KEEP (unselected will be removed):")

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

                echo
                log_warning "Will remove ${#to_remove[@]} packages:"
                printf '  - %s\n' "${to_remove[@]}"
                echo

                sudo pacman -Rns --noconfirm "${to_remove[@]}"
                log_success "Removed ${#to_remove[@]} packages"
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
                log_warning "This will remove ALL $total_unlisted unlisted packages"
                echo

                local all_to_remove=("${unlisted_official[@]}" "${unlisted_aur[@]}")
                sudo pacman -Rns --noconfirm "${all_to_remove[@]}"
                log_success "Removed $total_unlisted packages"
                ;;

            *)
                log_info "Cancelled"
                ;;
        esac
}

# Update system packages
packages_update() {
    log_section "Updating System"

    # Remove debug packages first
    local debug_packages=$(pacman -Qq | grep '\-debug$' 2>/dev/null || true)
    if [[ -n "$debug_packages" ]]; then
        log_info "Removing debug packages..."
        echo "$debug_packages" | xargs sudo pacman -Rdd --noconfirm 2>/dev/null || true
        echo
    fi

    if ! command -v yay &>/dev/null; then
        log_info "Updating system packages with pacman..."
        echo
        sudo pacman -Syu --noconfirm
        echo
        log_success "System update complete"
        return 0
    fi

    log_info "Updating all packages (official + AUR)..."
    echo
    yay -Syu --noconfirm --answerclean None --answerdiff None --removemake
    echo
    log_success "System update complete"
}

# Show package status
packages_status() {
    log_section "Package Status"
    
    # Count packages in lists
    local pkg_count=0
    local aur_count=0
    
    if [[ -f "$PACKAGES_FILE" ]]; then
        pkg_count=$(grep -cvE '^#|^$' "$PACKAGES_FILE")
    fi
    
    if [[ -f "$AUR_PACKAGES_FILE" ]]; then
        aur_count=$(grep -cvE '^#|^$' "$AUR_PACKAGES_FILE")
    fi
    
    show_info "Official packages in list" "$pkg_count"
    show_info "AUR packages in list" "$aur_count"
    show_info "Total in lists" "$((pkg_count + aur_count))"
    
    echo
    
    # Count installed packages
    local installed_official=$(pacman -Qe | wc -l)
    local installed_aur=$(pacman -Qm | wc -l)
    
    show_info "Official packages installed" "$((installed_official - installed_aur))"
    show_info "AUR packages installed" "$installed_aur"
    show_info "Total installed" "$installed_official"
}

# Audit system packages vs dotfiles lists
package_audit() {
    # Load package lists
    local packages=()
    local aur_packages=()

    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^#.*$ ]] && continue
        packages+=("$pkg")
    done < "$PACKAGES_FILE"

    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^#.*$ ]] && continue
        aur_packages+=("$pkg")
    done < "$AUR_PACKAGES_FILE"

    # Get installed packages
    local installed_official=()
    while IFS= read -r pkg; do
        installed_official+=("$pkg")
    done < <(pacman -Qeq | grep -vf <(pacman -Qmq))

    local installed_aur=()
    while IFS= read -r pkg; do
        installed_aur+=("$pkg")
    done < <(pacman -Qmq)

    # Find packages not in lists
    local unlisted=()
    for pkg in "${installed_official[@]}"; do
        if [[ ! " ${packages[@]} " =~ " ${pkg} " ]]; then
            unlisted+=("$pkg:official")
        fi
    done

    for pkg in "${installed_aur[@]}"; do
        if [[ ! " ${aur_packages[@]} " =~ " ${pkg} " ]]; then
            unlisted+=("$pkg:aur")
        fi
    done

    if [[ ${#unlisted[@]} -eq 0 ]]; then
        clear
        echo
        printf "\033[92m✓\033[0m \033[94mSystem is in sync with dotfiles\033[0m\n"
        echo
        read -p "Press Enter to continue..."
        return 0
    fi

    # Show unlisted packages
    clear
    echo
    printf "\033[90mFound ${#unlisted[@]} packages not in your dotfiles lists:\033[0m\n"
    for entry in "${unlisted[@]}"; do
        local pkg="${entry%%:*}"
        local type="${entry##*:}"
        printf "\033[94m  - %s\033[0m \033[90m(%s)\033[0m\n" "$pkg" "$type"
    done
    echo

    # Ask what to do
    local choice=$(gum choose --header "Add these packages to dotfiles?" \
        --height 15 --cursor.foreground 212 \
        "Yes, add all" \
        "Select which ones")

    [[ -z "$choice" ]] && return 1  # ESC pressed

    case "$choice" in
        "Yes, add all")
            for entry in "${unlisted[@]}"; do
                local pkg="${entry%%:*}"
                local type="${entry##*:}"
                if [[ "$type" == "aur" ]]; then
                    echo "$pkg" >> "$AUR_PACKAGES_FILE"
                else
                    echo "$pkg" >> "$PACKAGES_FILE"
                fi
            done
            sort -u "$PACKAGES_FILE" -o "$PACKAGES_FILE"
            sort -u "$AUR_PACKAGES_FILE" -o "$AUR_PACKAGES_FILE"
            echo
            printf "\033[92m✓\033[0m \033[94mAdded ${#unlisted[@]} packages to your lists\033[0m\n"
            return 0
            ;;
        "Select which ones")
            local options=()
            for entry in "${unlisted[@]}"; do
                local pkg="${entry%%:*}"
                local type="${entry##*:}"
                options+=("$pkg ($type)")
            done

            clear
            echo
            printf "\033[94mSelect packages to add to dotfiles\033[0m\n"
            printf "\033[90m(space to select, enter to confirm - unchecked will be ignored)\033[0m\n"
            echo

            local selected=()
            readarray -t selected < <(gum choose --no-limit --height 15 --cursor.foreground 212 "${options[@]}")
            local gum_exit=$?

            if [[ $gum_exit -ne 0 ]] || [[ ${#selected[@]} -eq 0 ]]; then
                # ESC or nothing selected - return 1 to skip Press Enter
                return 1
            fi

            # Add selected packages
            local added_count=0
            for item in "${selected[@]}"; do
                local pkg="${item%% (*}"
                local type="${item##*(}"
                type="${type%)}"

                if [[ "$type" == "aur" ]]; then
                    echo "$pkg" >> "$AUR_PACKAGES_FILE"
                else
                    echo "$pkg" >> "$PACKAGES_FILE"
                fi
                ((added_count++))
            done

            if [[ $added_count -gt 0 ]]; then
                sort -u "$PACKAGES_FILE" -o "$PACKAGES_FILE"
                sort -u "$AUR_PACKAGES_FILE" -o "$AUR_PACKAGES_FILE"
                echo
                printf "\033[92m✓\033[0m \033[94mAdded $added_count packages to your lists\033[0m\n"
                return 0
            else
                # Nothing added - return 1
                return 1
            fi
            ;;
        *)
            # "No, skip" or ESC - return 1
            return 1
            ;;
    esac
}

