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

        if confirm "Remove these packages?"; then
            log_info "Removing packages..."
            sudo pacman -Rns --noconfirm "${to_remove[@]}"
            echo
            log_success "Packages removed"
        else
            log_warning "Skipped package removal"
        fi
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

    # Check for packages not in lists
    log_info "Checking for unlisted packages..."
    local installed_official=()
    while IFS= read -r pkg; do
        installed_official+=("$pkg")
    done < <(pacman -Qeq | grep -vf <(pacman -Qmq))

    local installed_aur=()
    while IFS= read -r pkg; do
        installed_aur+=("$pkg")
    done < <(pacman -Qmq)

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

    if [[ ${#unlisted[@]} -gt 0 ]]; then
        log_warning "Found ${#unlisted[@]} packages not in your dotfiles lists"
        echo
        log_info "Unlisted packages:"
        for entry in "${unlisted[@]}"; do
            local pkg="${entry%%:*}"
            local type="${entry##*:}"
            printf '  - %s (%s)\n' "$pkg" "$type"
        done
        echo

        if command -v gum &>/dev/null; then
            local choice=$(gum choose --header "What would you like to do?" \
                "Add all to package lists" \
                "Select which to keep (unchecked will be removed)" \
                "Skip for now")
        else
            echo "What would you like to do?"
            echo "  1) Add all to package lists"
            echo "  2) Select which to keep (unchecked will be removed)"
            echo "  3) Skip for now"
            read -p "Choice [1-3]: " choice_num
            case "$choice_num" in
                1) choice="Add all to package lists" ;;
                2) choice="Select which to keep (unchecked will be removed)" ;;
                *) choice="Skip for now" ;;
            esac
        fi

        case "$choice" in
            "Add all to package lists")
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
                log_success "Added ${#unlisted[@]} packages to your lists"
                ;;
            "Select which to keep (unchecked will be removed)")
                echo
                local options=()
                for entry in "${unlisted[@]}"; do
                    local pkg="${entry%%:*}"
                    local type="${entry##*:}"
                    options+=("$pkg ($type)")
                done

                local selected=()
                local cancelled=false

                if command -v gum &>/dev/null; then
                    log_info "Select packages to KEEP (space to select, enter to confirm)"
                    log_warning "Unchecked packages will be REMOVED from your system"
                    echo
                    readarray -t selected < <(gum choose --no-limit "${options[@]}" 2>/dev/null)
                    local gum_exit=$?

                    # Check if user cancelled (ESC pressed)
                    if [[ $gum_exit -ne 0 ]]; then
                        echo
                        log_info "Cancelled - no changes made"
                        cancelled=true
                    fi
                else
                    log_warning "Interactive selection requires 'gum'. Adding all packages..."
                    selected=("${options[@]}")
                fi

                # Skip rest of logic if cancelled - use early termination of case branch
                if ! $cancelled; then
                    # Add selected packages to lists
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
                fi

                # Remove unselected packages
                local to_remove=()
                for entry in "${unlisted[@]}"; do
                    local pkg="${entry%%:*}"
                    local type="${entry##*:}"
                    local item="$pkg ($type)"
                    local found=false

                    for sel in "${selected[@]}"; do
                        if [[ "$sel" == "$item" ]]; then
                            found=true
                            break
                        fi
                    done

                    if ! $found; then
                        to_remove+=("$pkg")
                    fi
                done

                echo
                if [[ ${#to_remove[@]} -gt 0 ]]; then
                    log_warning "About to remove ${#to_remove[@]} unchecked packages:"
                    printf '  - %s\n' "${to_remove[@]}"
                    echo

                    if confirm "Remove these ${#to_remove[@]} packages?"; then
                        log_info "Removing packages..."
                        sudo pacman -Rns --noconfirm "${to_remove[@]}"
                        echo
                        log_success "Kept $added_count packages, removed ${#to_remove[@]} packages"
                    else
                        log_info "Cancelled removal - packages kept"
                        if [[ $added_count -gt 0 ]]; then
                            log_success "Added $added_count packages to your lists"
                        fi
                    fi
                    elif [[ $added_count -gt 0 ]]; then
                        log_success "Added $added_count packages to your lists"
                    else
                        log_info "No packages selected - none added or removed"
                    fi
                fi  # End of if ! $cancelled
                ;;
            *)
                log_info "Skipped unlisted packages"
                ;;
        esac
        echo
    else
        log_success "All installed packages are in your dotfiles lists"
        echo
    fi

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
        if confirm "Install ${#missing_official[@]} official packages?"; then
            log_info "Installing official packages..."
            echo
            sudo pacman -S --needed "${missing_official[@]}"
            echo
            log_success "Official packages installed"
        else
            log_warning "Skipped official package installation"
        fi
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
            if confirm "Install ${#missing_aur[@]} AUR packages?"; then
                log_info "Installing AUR packages..."
                echo
                yay -S --needed "${missing_aur[@]}"
                echo
                log_success "AUR packages installed"
            else
                log_warning "Skipped AUR package installation"
            fi
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
        if confirm "Update package lists?"; then
            cp "$official_temp" "$PACKAGES_FILE"
            cp "$aur_packages_temp" "$AUR_PACKAGES_FILE"
            
            log_success "Package lists updated"
            show_info "Official packages" "$(wc -l < "$PACKAGES_FILE")"
            show_info "AUR packages" "$(wc -l < "$AUR_PACKAGES_FILE")"
        else
            log_warning "Package lists not updated"
        fi
    else
        log_success "Package lists are already up to date"
    fi
    
    # Cleanup
    rm -f "$official_temp" "$aur_packages_temp"
}

# Update system packages
packages_update() {
    log_section "Updating System"
    
    if ! command -v yay &>/dev/null; then
        log_warning "yay not found, using pacman only"
        echo
        if confirm "Update system with pacman?"; then
            log_info "Updating system packages..."
            echo
            sudo pacman -Syu --noconfirm
            echo
            log_success "System update complete"
        else
            log_info "Update cancelled"
        fi
    else
        echo
        if confirm "Update system with yay (includes AUR)?"; then
            log_info "Updating all packages (official + AUR)..."
            echo
            yay -Syu --noconfirm
            echo
            log_success "System update complete"
        else
            log_info "Update cancelled"
        fi
    fi
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

