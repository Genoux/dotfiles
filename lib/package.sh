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

# Install packages from lists
packages_install() {
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
    
    # Read AUR packages
    local aur_packages=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^#.*$ ]] && continue
        aur_packages+=("$pkg")
    done < "$AUR_PACKAGES_FILE"
    
    log_info "Found ${#packages[@]} official packages and ${#aur_packages[@]} AUR packages"
    echo
    
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
        if confirm "Install ${#missing_official[@]} official packages?"; then
            run_with_spinner "Installing official packages" \
                sudo pacman -S --needed --noconfirm "${missing_official[@]}"
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
            run_with_spinner "Installing yay" bash -c '
                sudo pacman -S --needed --noconfirm base-devel git
                cd /tmp
                rm -rf yay
                git clone https://aur.archlinux.org/yay.git
                cd yay
                makepkg -si --noconfirm
            '
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
            if confirm "Install ${#missing_aur[@]} AUR packages?"; then
                run_with_spinner "Installing AUR packages" \
                    yay -S --needed --noconfirm "${missing_aur[@]}"
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
        if confirm "Update system with pacman?"; then
            run_with_spinner "Updating system" sudo pacman -Syu --noconfirm
        fi
    else
        if confirm "Update system with yay?"; then
            run_with_spinner "Updating system" yay -Syu --noconfirm
        fi
    fi
    
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

