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

# Ensure yay is installed (system depends on it)
ensure_yay_installed() {
    if command -v yay &>/dev/null; then
        return 0
    fi

    log_info "Installing yay (AUR helper - required by system)..."
    echo

    # Install dependencies
    log_info "Installing base-devel and git..."
    sudo pacman -S --needed --noconfirm base-devel git
    echo

    # Clone and build yay
    log_info "Cloning yay repository..."
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    git clone --depth=1 --progress https://aur.archlinux.org/yay.git
    cd yay
    echo

    log_info "Building yay from source..."
    # Build package first (non-interactive)
    makepkg -s --noconfirm
    echo
    
    log_info "Installing yay package..."
    # Install the built package (non-interactive)
    sudo pacman -U --noconfirm yay-*.pkg.tar.zst
    echo

    # Cleanup
    cd - >/dev/null
    rm -rf "$temp_dir"
    echo

    if command -v yay &>/dev/null; then
        log_success "yay installed successfully"
    else
        fatal_error "Failed to install yay"
    fi

    echo
}

# Ensure Node.js is installed (required for many AUR packages)
ensure_nodejs_installed() {
    if command -v node &>/dev/null; then
        return 0
    fi

    log_info "Installing Node.js (required for AUR packages)..."
    echo

    # Install Node.js with corepack
    log_info "Installing Node.js..."
    sudo pacman -S --needed --noconfirm nodejs npm
    echo

    # Enable corepack (it should be available after nodejs installation)
    log_info "Enabling corepack..."
    if command -v corepack &>/dev/null; then
        sudo corepack enable
        echo
    else
        log_warning "corepack not found, but Node.js is installed"
        echo
    fi

    if command -v node &>/dev/null; then
        log_success "Node.js installed successfully"
    else
        fatal_error "Failed to install Node.js"
    fi

    echo
}

# Prepare system for package installation
packages_prepare() {
    log_section "Preparing System"

    # Ensure yay is installed (system depends on it)
    ensure_yay_installed

    # Ensure Node.js is installed (required for many AUR packages)
    ensure_nodejs_installed

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

    # Enable multilib repository if needed
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        log_info "Enabling multilib repository..."
        sudo sed -i 's/^#\[multilib\]/\[multilib\]/' /etc/pacman.conf
        sudo sed -i '/^\[multilib\]$/,/^\[/ s/^#Include = \/etc\/pacman\.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/' /etc/pacman.conf
        echo
    fi

    # Sync package databases
    log_info "Synchronizing package databases..."
    sudo pacman -Sy --noconfirm
    echo
    log_success "Package databases synchronized"
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
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PACMAN] Installing packages: ${missing_official[*]}" >> "$DOTFILES_LOG_FILE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PACMAN] Starting installation..." >> "$DOTFILES_LOG_FILE"
        
        # Run pacman with automatic answers to all prompts
        # Use printf to automatically answer provider selection (default=1) and proceed (Y)
        printf "1\nY\n" | sudo pacman -S --needed --noconfirm "${missing_official[@]}"
        local pacman_exit_code=$?
        
        if [[ $pacman_exit_code -eq 0 ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PACMAN] Installation completed successfully" >> "$DOTFILES_LOG_FILE"
            log_success "Official packages installed"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PACMAN] Installation completed with some failures (exit code: $pacman_exit_code)" >> "$DOTFILES_LOG_FILE"
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
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Refreshing sudo session for yay installation..." >> "$DOTFILES_LOG_FILE"
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
        
        # 2. Temporarily neutralize npm config (affects: claude-desktop, etc.)
        local npmrc_backup=""
        if [[ -f "$HOME/.npmrc" ]]; then
            npmrc_backup="$HOME/.npmrc.aur-install-backup"
            log_info "Temporarily moving ~/.npmrc to avoid nvm conflicts..."
            mv "$HOME/.npmrc" "$npmrc_backup" 2>/dev/null || true
        fi
        
        # Export env vars to neutralize npm config
        export NPM_CONFIG_USERCONFIG=/dev/null
        unset NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG npm_config_globalconfig
        echo
        
        # Resolve package conflicts
        local conflicts_to_remove=()
        for pkg in "${missing_aur[@]}"; do
            # Check for common conflicts (e.g., walker-bin vs walker-git)
            if [[ "$pkg" == *"-bin" ]]; then
                local base_name="${pkg%-bin}"
                local git_variant="${base_name}-git"
                if pacman -Q "$git_variant" &>/dev/null; then
                    log_info "Detected conflict: $git_variant installed, but $pkg requested"
                    conflicts_to_remove+=("$git_variant")
                fi
            elif [[ "$pkg" == *"-git" ]]; then
                local base_name="${pkg%-git}"
                local bin_variant="${base_name}-bin"
                if pacman -Q "$bin_variant" &>/dev/null; then
                    log_info "Detected conflict: $bin_variant installed, but $pkg requested"
                    conflicts_to_remove+=("$bin_variant")
                fi
            fi
        done
        
        # Remove conflicting packages before installation
        if [[ ${#conflicts_to_remove[@]} -gt 0 ]]; then
            log_info "Resolving package conflicts..."
            printf '  - %s\n' "${conflicts_to_remove[@]}"
            echo
            yay -Rns --noconfirm "${conflicts_to_remove[@]}" 2>/dev/null || true
            echo
        fi
        
        # Install missing AUR packages
        log_info "Installing ${#missing_aur[@]} AUR packages..."
        echo
        log_info "Packages to install: ${missing_aur[*]}"
        echo
        log_info "Installing AUR packages..."
        echo
        # Refresh sudo session before yay (yay calls pacman which needs sudo)
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Refreshing sudo session..." >> "$DOTFILES_LOG_FILE"
        sudo -v || {
            log_error "Failed to refresh sudo session"
            return 1
        }
        
        # Install AUR packages directly (yay will handle sudo prompts)
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Installing packages: ${missing_aur[*]}" >> "$DOTFILES_LOG_FILE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Starting installation..." >> "$DOTFILES_LOG_FILE"
        
        # Run yay with automatic answers to all prompts
        # Use printf to automatically answer any provider selections and proceed confirmations
        # --refresh: Download fresh package databases from AUR
        printf "1\nY\n" | yay -S --needed --noconfirm --refresh --answerclean None --answerdiff None --removemake "${missing_aur[@]}"
        local yay_exit_code=$?
        
        # Restore ~/.npmrc if we moved it
        if [[ -n "$npmrc_backup" && -f "$npmrc_backup" ]]; then
            log_info "Restoring ~/.npmrc..."
            mv "$npmrc_backup" "$HOME/.npmrc" 2>/dev/null || true
        fi
        
        if [[ $yay_exit_code -eq 0 ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Installation completed successfully" >> "$DOTFILES_LOG_FILE"
            log_success "AUR packages installed"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [YAY] Installation completed with some failures (exit code: $yay_exit_code)" >> "$DOTFILES_LOG_FILE"
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

# Sync package lists from system
packages_sync() {
    log_section "Syncing Package Lists"
    
    log_info "Scanning installed packages..."
    
    # Get all explicitly installed packages and categorize them properly
    local aur_packages_temp=$(mktemp)
    local official_temp=$(mktemp)
    
    # Fast categorization: use pacman's built-in categorization
    # Get official packages (explicitly installed, not from AUR)
    pacman -Qeq | grep -vf <(pacman -Qmq) >> "$official_temp"
    
    # Get AUR packages (explicitly installed from AUR)
    pacman -Qmq >> "$aur_packages_temp"
    
    # Sort the files
    sort "$aur_packages_temp" -o "$aur_packages_temp"
    sort "$official_temp" -o "$official_temp"
    
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

    # Check if any "missing" packages are actually installed as dependencies
    local deps_as_explicit=()
    for pkg in "${missing_official[@]}" "${missing_aur[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then
            deps_as_explicit+=("$pkg")
        fi
    done
    
    # Offer smart actions based on what's found
    local options=()

    if [[ ${#deps_as_explicit[@]} -gt 0 ]]; then
        options+=("Mark ${#deps_as_explicit[@]} dependency packages as explicit (already installed)")
    fi
    [[ $total_missing -gt 0 ]] && options+=("Install missing packages ($total_missing)")
    [[ $total_missing -gt 0 ]] && options+=("Remove missing from dotfiles ($total_missing)")
    [[ $total_extra -gt 0 ]] && options+=("Add extra to dotfiles ($total_extra)")
    [[ $total_extra -gt 0 ]] && options+=("Remove extra from system ($total_extra)")
    [[ $total_extra -gt 0 ]] && options+=("Select which to keep/remove")
    [[ $total_missing -gt 0 && $total_extra -gt 0 ]] && options+=("Full sync (install + add)")

    local action=$(gum choose --header "What would you like to do?" "${options[@]}")
    [[ -z "$action" ]] && return 1  # ESC pressed

    case "$action" in
        "Mark"*"dependency packages as explicit"*)
            log_info "Marking ${#deps_as_explicit[@]} packages as explicitly installed..."
            echo
            printf '  - %s\n' "${deps_as_explicit[@]}"
            echo
            sudo pacman -D --asexplicit "${deps_as_explicit[@]}"
            log_success "Packages marked as explicit"
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

            # Remove from packages.txt
            for pkg in "${missing_official[@]}"; do
                sed -i "/^${pkg}$/d" "$PACKAGES_FILE"
            done

            # Remove from aur-packages.txt
            for pkg in "${missing_aur[@]}"; do
                sed -i "/^${pkg}$/d" "$AUR_PACKAGES_FILE"
            done

            log_success "Removed $total_missing packages from dotfiles"
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
            log_info "Checking which of $total_extra packages can be safely removed..."
            echo
            local all_extra=("${extra_official[@]}" "${extra_aur[@]}")
            
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
            log_info "Full sync: Installing missing + adding extras to dotfiles..."
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
            
            # Add extra packages to dotfiles
            echo
            log_info "Adding extras to dotfiles..."
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

# Update system packages
packages_update() {
    log_section "Updating System"

    # Validate sudo access upfront
    log_info "Validating sudo access..."
    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges"
        return 1
    fi
    echo

    # Remove debug packages first
    local debug_packages=$(pacman -Qq | grep '\-debug$' 2>/dev/null || true)
    if [[ -n "$debug_packages" ]]; then
        log_info "Removing debug packages..."
        echo "$debug_packages" | xargs sudo pacman -Rdd --noconfirm 2>/dev/null || true
        echo
    fi

    # Step 1: Update official repositories first (root)
    log_info "Updating official repositories (pacman)..."
    if ! sudo pacman -Syu --noconfirm; then
        log_error "pacman repo update failed"
        return 1
    fi
    echo

    # Ensure yay is installed for AUR step
    ensure_yay_installed

    # Step 2: Update AUR packages (user)
    # Neutralize user npm config that breaks nvm-based PKGBUILDs (e.g., claude-desktop)
    # Some AUR helpers/makepkg may ignore exported env; safest is to temporarily
    # move ~/.npmrc out of the way if it exists and restore it afterwards.
    local npmrc_backup=""
    if [[ -f "$HOME/.npmrc" ]]; then
        npmrc_backup="$HOME/.npmrc.dotfiles-backup-$(date +%s)"
        mv "$HOME/.npmrc" "$npmrc_backup" 2>/dev/null || true
    fi
    # Also try to neutralize env-based npm configs
    export NPM_CONFIG_USERCONFIG=/dev/null
    unset NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG npm_config_globalconfig

    log_info "Updating AUR packages (yay)..."
    local aur_exit=0
    local aur_output

    aur_output=$(yay -Sua --noconfirm --answerclean N --answerdiff N 2>&1) || aur_exit=$?
    echo "$aur_output"
    echo

    if [[ $aur_exit -ne 0 ]]; then
        log_warning "AUR update failed (exit $aur_exit) - retrying..."
        aur_exit=0
        aur_output=$(yay -Sua --noconfirm --answerclean N --answerdiff N 2>&1) || aur_exit=$?
        echo "$aur_output"
        echo
    fi

    # Restore ~/.npmrc if we moved it
    if [[ -n "$npmrc_backup" && -f "$npmrc_backup" ]]; then
        mv "$npmrc_backup" "$HOME/.npmrc" 2>/dev/null || true
    fi

    if [[ $aur_exit -eq 0 ]]; then
        log_success "System update complete"
        return 0
    else
        log_error "AUR update failed (exit code: $aur_exit)"
        if echo "$aur_output" | grep -qi "TLS handshake timeout"; then
            log_error "Network timeout talking to AUR; try again later or check connectivity/DNS"
        fi
        if echo "$aur_output" | grep -qi "A failure occurred in prepare\(\)"; then
            log_error "AUR build prepare() failed (often due to user npm prefix/globalconfig). We neutralized ~/.npmrc, but if it persists, try building the package alone with: yay -S <pkg> --debug"
        fi
        return 1
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
