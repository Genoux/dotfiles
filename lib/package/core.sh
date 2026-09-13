#!/bin/bash
# Core package system operations (yay, Node.js, system preparation)

# Ensure yay is installed (system depends on it). Called only after the
# official packages phase's `-Syu` has run (from install_aur_packages), so
# base-devel/git — tracked in packages/arch.package — are already installed;
# this must never do its own `pacman -S` here, which would be a partial
# install sandwiched between whatever `-Sy` most recently ran and the next
# full `-Syu` (see lib/package/preflight.sh's sync_pacman_db).
ensure_yay_installed() {
    if command -v yay &>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] yay is already installed" >> "$DOTFILES_LOG_FILE"
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Install yay (AUR helper)" >> "$DOTFILES_LOG_FILE"

    if ! command -v git &>/dev/null || ! command -v makepkg &>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: git/base-devel not present" >> "$DOTFILES_LOG_FILE"
        finish_logging
        sleep 1
        stop_log_monitor
        log_error "git and base-devel are required to build yay — check packages/arch.package installed correctly"
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

    # yay/nodejs are no longer bootstrapped here — nodejs is tracked in
    # packages/arch.package (installed by the official phase's single -Syu),
    # and ensure_yay_installed runs later, from install_aur_packages, after
    # that -Syu has already put base-devel/git in place. Mirror ranking was
    # removed outright (not merely relocated): it was a `pacman -S reflector`
    # + rank pass whose only purpose is faster download speed, not
    # correctness, and it doesn't belong ahead of a full sync+upgrade either
    # way — archinstall already ranks mirrors during initial setup, and nothing
    # else in this repo depends on reflector being present. Multilib enabling
    # moved to preflight's ensure_multilib_enabled — lib32-* names (GPU/Wine
    # packages) need it enabled before check_package_names validates them,
    # not after.

    # No separate `pacman -Sy` here: preflight's sync_pacman_db already synced
    # once, and install_official_packages's `-Syu` (the very next pacman call
    # in this phase) re-syncs anyway — an extra -Sy here only widened the
    # window between a sync and the eventual upgrade for no benefit.

    finish_logging
    sleep 1
    stop_log_monitor true

    log_success "System preparation complete"
}
