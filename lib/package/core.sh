#!/bin/bash
# Core package system operations (yay, Node.js, system preparation)

# Ensure yay is installed (system depends on it)
ensure_yay_installed() {
    if command -v yay &>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] yay is already installed" >> "$DOTFILES_LOG_FILE"
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Install yay (AUR helper)" >> "$DOTFILES_LOG_FILE"

    # Install dependencies
    if ! run_command_logged "Install base-devel and git" sudo pacman -S --needed --noconfirm base-devel git; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Install yay dependencies" >> "$DOTFILES_LOG_FILE"
        finish_logging
        sleep 1
        stop_log_monitor
        log_error "Failed to install yay dependencies"
        return 1
    fi

    # Clone and build yay
    local temp_dir=$(mktemp -d)
    if ! run_command_logged "Clone yay repository" bash -c "cd '$temp_dir' && git clone --depth=1 https://aur.archlinux.org/yay.git"; then
        rm -rf "$temp_dir"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Clone yay repository" >> "$DOTFILES_LOG_FILE"
        finish_logging
        sleep 1
        stop_log_monitor
        log_error "Failed to clone yay repository"
        return 1
    fi

    if ! run_command_logged "Build yay from source" bash -c "cd '$temp_dir/yay' && makepkg -s --noconfirm"; then
        rm -rf "$temp_dir"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Build yay" >> "$DOTFILES_LOG_FILE"
        finish_logging
        sleep 1
        stop_log_monitor
        log_error "Failed to build yay"
        return 1
    fi

    if ! run_command_logged "Install yay package" bash -c "cd '$temp_dir/yay' && sudo pacman -U --noconfirm yay-*.pkg.tar.zst"; then
        rm -rf "$temp_dir"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Install yay package" >> "$DOTFILES_LOG_FILE"
        finish_logging
        sleep 1
        stop_log_monitor
        log_error "Failed to install yay package"
        return 1
    fi

    # Cleanup
    rm -rf "$temp_dir"

    if command -v yay &>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Install yay successfully" >> "$DOTFILES_LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: yay not found after installation" >> "$DOTFILES_LOG_FILE"
        finish_logging
        sleep 1
        stop_log_monitor
        log_error "Failed to install yay"
        return 1
    fi
}

# Ensure Node.js is installed (required for many AUR packages)
ensure_nodejs_installed() {
    if command -v node &>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Node.js is already installed" >> "$DOTFILES_LOG_FILE"
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Install Node.js" >> "$DOTFILES_LOG_FILE"

    # Install Node.js with npm
    if ! run_command_logged "Install Node.js and npm" sudo pacman -S --needed --noconfirm nodejs npm; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Install Node.js" >> "$DOTFILES_LOG_FILE"
        finish_logging
        sleep 1
        stop_log_monitor
        log_error "Failed to install Node.js"
        return 1
    fi

    # Enable corepack
    if command -v corepack &>/dev/null; then
        if ! run_command_logged "Enable corepack" sudo corepack enable; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Failed to enable corepack" >> "$DOTFILES_LOG_FILE"
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: corepack not found" >> "$DOTFILES_LOG_FILE"
    fi

    if command -v node &>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Install Node.js successfully" >> "$DOTFILES_LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Node.js not found after installation" >> "$DOTFILES_LOG_FILE"
        finish_logging
        sleep 1
        stop_log_monitor
        log_error "Failed to install Node.js"
        return 1
    fi
}

# Prepare system for package installation
packages_prepare() {
    # Validate sudo access upfront
    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges"
        return 1
    fi

    # Initialize logging and start monitor
    init_logging "package"
    start_log_monitor

    # Ensure yay is installed
    ensure_yay_installed

    # Ensure Node.js is installed
    ensure_nodejs_installed

    # Check if mirrors need updating (older than 30 days)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Check mirror list" >> "$DOTFILES_LOG_FILE"
    local mirrorlist="/etc/pacman.d/mirrorlist"
    local needs_update=false

    if [[ -f "$mirrorlist" ]]; then
        local mirror_age=$(($(date +%s) - $(stat -c %Y "$mirrorlist")))
        local update_threshold=$((30 * 24 * 60 * 60))

        if [[ $mirror_age -gt $update_threshold ]]; then
            needs_update=true
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mirror list is older than 30 days, needs update" >> "$DOTFILES_LOG_FILE"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mirror list is recent (updated $(date -d @$(stat -c %Y "$mirrorlist") '+%Y-%m-%d'))" >> "$DOTFILES_LOG_FILE"
        fi
    else
        needs_update=true
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mirror list not found, needs creation" >> "$DOTFILES_LOG_FILE"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Check mirror list" >> "$DOTFILES_LOG_FILE"

    if $needs_update; then
        if ! command -v reflector &>/dev/null; then
            run_command_logged "Install reflector" sudo pacman -S --needed --noconfirm reflector
        fi

        # Backup existing mirrorlist
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Backup mirrorlist" >> "$DOTFILES_LOG_FILE"
        sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup 2>> "$DOTFILES_LOG_FILE" || true
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Backup mirrorlist" >> "$DOTFILES_LOG_FILE"

        # Detect country from locale (fallback to worldwide)
        local mirror_country="US"
        if command -v locale &>/dev/null; then
            local locale_country=$(locale | grep -oP 'LANG=\w+_\K[A-Z]{2}' | head -1)
            [[ -n "$locale_country" ]] && mirror_country="$locale_country"
        fi
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using mirror country: $mirror_country" >> "$DOTFILES_LOG_FILE"

        # Rank mirrors by speed (try country-specific, fallback to worldwide)
        if run_command_logged "Rank mirrors by speed" sudo reflector --country "$mirror_country" --age 6 --protocol https --sort rate --fastest 10 --connection-timeout 3 --download-timeout 5 --save /etc/pacman.d/mirrorlist.new; then
            if [[ -s /etc/pacman.d/mirrorlist.new ]]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Apply new mirrorlist" >> "$DOTFILES_LOG_FILE"
                sudo mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Mirrors updated successfully" >> "$DOTFILES_LOG_FILE"
            else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Generated mirrorlist is empty" >> "$DOTFILES_LOG_FILE"
                sudo rm -f /etc/pacman.d/mirrorlist.new
            fi
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Reflector failed, keeping existing mirrors" >> "$DOTFILES_LOG_FILE"
            sudo rm -f /etc/pacman.d/mirrorlist.new
        fi
    fi

    # Enable multilib repository if needed
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Enable multilib repository" >> "$DOTFILES_LOG_FILE"
        sudo sed -i 's/^#\[multilib\]/\[multilib\]/' /etc/pacman.conf 2>> "$DOTFILES_LOG_FILE"
        sudo sed -i '/^\[multilib\]$/,/^\[/ s/^#Include = \/etc\/pacman\.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/' /etc/pacman.conf 2>> "$DOTFILES_LOG_FILE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Enable multilib repository" >> "$DOTFILES_LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] multilib repository already enabled" >> "$DOTFILES_LOG_FILE"
    fi

    # Sync package databases
    run_command_logged "Sync package databases" sudo pacman -Sy --noconfirm

    finish_logging
    sleep 1
    stop_log_monitor true

    log_success "System preparation complete"
}
