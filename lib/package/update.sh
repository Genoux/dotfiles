#!/bin/bash
# System package updates and conflict resolution

# Detect and resolve AUR packages that conflict with official packages
resolve_aur_official_conflicts() {
    log_info "Checking for AUR packages conflicting with official packages..."

    # Get all AUR packages
    local aur_packages=($(pacman -Qmq 2>/dev/null || true))

    if [[ ${#aur_packages[@]} -eq 0 ]]; then
        return 0
    fi

    # Refresh package databases to check for conflicts
    sudo pacman -Sy --noconfirm >/dev/null 2>&1 || true

    local conflicts_to_remove=()

    for aur_pkg in "${aur_packages[@]}"; do
        # Check if this AUR package provides a base package name (without -git/-bin suffix)
        local base_name="${aur_pkg%-git}"
        base_name="${base_name%-bin}"

        # Skip if it's already the base name
        if [[ "$aur_pkg" == "$base_name" ]]; then
            continue
        fi

        # Check if an official package with the base name exists and conflicts
        if pacman -Si "$base_name" &>/dev/null; then
            local aur_conflicts=$(pacman -Qi "$aur_pkg" 2>/dev/null | grep "Conflicts With" | cut -d: -f2 | xargs)
            if [[ "$aur_conflicts" == *"$base_name"* ]]; then
                log_info "Detected conflict: $aur_pkg (AUR) conflicts with $base_name (official)"
                conflicts_to_remove+=("$aur_pkg")
            fi
        fi
    done

    if [[ ${#conflicts_to_remove[@]} -eq 0 ]]; then
        return 0
    fi

    log_info "Found ${#conflicts_to_remove[@]} conflicting AUR package(s):"
    printf '  - %s\n' "${conflicts_to_remove[@]}"
    echo

    log_info "Force-removing conflicting AUR packages (will be replaced by official packages during upgrade)..."
    sudo pacman -Rdd --noconfirm "${conflicts_to_remove[@]}" 2>&1 || {
        log_error "Failed to remove conflicting AUR packages"
        log_info "Manual resolution required. Try:"
        printf '  sudo pacman -Rdd %s\n' "${conflicts_to_remove[*]}"
        echo
        return 1
    }
    echo

    # Clean up package files
    log_info "Cleaning up package lists..."
    local files_updated=false

    if [[ -f "$AUR_PACKAGES_FILE" ]]; then
        local temp_file=$(mktemp)
        local removed_count=0

        while IFS= read -r line; do
            local should_keep=true
            for pkg in "${conflicts_to_remove[@]}"; do
                if [[ "$line" == "$pkg" ]]; then
                    should_keep=false
                    ((removed_count++))
                    break
                fi
            done
            if $should_keep; then
                echo "$line" >> "$temp_file"
            fi
        done < "$AUR_PACKAGES_FILE"

        if [[ $removed_count -gt 0 ]]; then
            mv "$temp_file" "$AUR_PACKAGES_FILE"
            files_updated=true
            log_info "Removed $removed_count package(s) from aur-packages.package"
        else
            rm -f "$temp_file"
        fi
    fi

    # Add official packages to packages.package if they're not already there
    if [[ -f "$PACKAGES_FILE" ]]; then
        local temp_file=$(mktemp)
        local added_count=0

        cp "$PACKAGES_FILE" "$temp_file"

        for aur_pkg in "${conflicts_to_remove[@]}"; do
            local base_name="${aur_pkg%-git}"
            base_name="${base_name%-bin}"

            if pacman -Si "$base_name" &>/dev/null; then
                if ! grep -qxF "$base_name" "$temp_file" 2>/dev/null; then
                    echo "$base_name" >> "$temp_file"
                    ((added_count++))
                fi
            fi
        done

        if [[ $added_count -gt 0 ]]; then
            sort -u "$temp_file" -o "$temp_file"
            mv "$temp_file" "$PACKAGES_FILE"
            files_updated=true
            log_info "Added $added_count official package(s) to packages.package"
        else
            rm -f "$temp_file"
        fi
    fi

    if $files_updated; then
        log_success "Package lists updated"
    fi

    log_success "Removed ${#conflicts_to_remove[@]} conflicting AUR package(s)"
    log_info "Official packages will be installed during system upgrade"
    echo
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

    # Resolve AUR vs official package conflicts before updating
    if ! resolve_aur_official_conflicts; then
        log_error "Failed to resolve package conflicts. Update cannot proceed."
        return 1
    fi

    # Update official repositories first
    log_info "Updating official repositories (pacman)..."
    if ! sudo pacman -Syu --noconfirm; then
        log_error "pacman repo update failed"
        return 1
    fi
    echo

    # Ensure yay is installed for AUR step
    ensure_yay_installed

    # Update AUR packages - Neutralize user npm config that breaks nvm-based PKGBUILDs
    local npmrc_backup=""
    if [[ -f "$HOME/.npmrc" ]]; then
        npmrc_backup="$HOME/.npmrc.dotfiles-backup-$(date +%s)"
        mv "$HOME/.npmrc" "$npmrc_backup" 2>/dev/null || true
    fi
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
