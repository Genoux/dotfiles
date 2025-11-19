#!/bin/bash
# Core package system operations (yay, Node.js, system preparation)

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
    makepkg -s --noconfirm
    echo

    log_info "Installing yay package..."
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

    # Enable corepack
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

    # Ensure yay is installed
    ensure_yay_installed

    # Ensure Node.js is installed
    ensure_nodejs_installed

    # Check if mirrors need updating (older than 30 days)
    local mirrorlist="/etc/pacman.d/mirrorlist"
    local needs_update=false

    if [[ -f "$mirrorlist" ]]; then
        local mirror_age=$(($(date +%s) - $(stat -c %Y "$mirrorlist")))
        local update_threshold=$((30 * 24 * 60 * 60))

        if [[ $mirror_age -gt $update_threshold ]]; then
            needs_update=true
            log_info "Mirror list is older than 30 days"
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
            run_with_spinner "Installing reflector..." bash -c 'sudo pacman -S --needed --noconfirm reflector > /dev/null 2>&1'
            log_success "Reflector installed"
            echo
        fi

        # Backup existing mirrorlist
        sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

        if ! run_with_spinner "Ranking mirrors by speed..." sudo reflector \
            --country US \
            --age 6 \
            --protocol https \
            --sort rate \
            --fastest 10 \
            --connection-timeout 3 \
            --download-timeout 5 \
            --save /etc/pacman.d/mirrorlist.new 2>&1 | grep -v "WARNING"; then
            log_error "Reflector failed, keeping existing mirrors"
            sudo rm -f /etc/pacman.d/mirrorlist.new
        elif [[ ! -s /etc/pacman.d/mirrorlist.new ]]; then
            log_error "Generated mirrorlist is empty, restoring backup"
            sudo rm -f /etc/pacman.d/mirrorlist.new
        else
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
    run_with_spinner "Synchronizing package databases..." bash -c 'sudo pacman -Sy --noconfirm > /dev/null 2>&1'
    echo
    log_success "Package databases synchronized"
    echo
}
