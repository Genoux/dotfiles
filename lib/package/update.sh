#!/bin/bash
# System package updates and conflict resolution
# Requires: gum (charmbracelet/gum)

# Update system packages
packages_update() {
    # Validate sudo access upfront
    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges"
        return 1
    fi

    # Initialize logging and start monitor
    init_logging "package"
    start_log_monitor

    # Remove debug packages first (silent if none found)
    local debug_packages=$(pacman -Qq | grep '\-debug$' 2>/dev/null || true)
    if [[ -n "$debug_packages" ]]; then
        run_command_logged "Remove debug packages" bash -c "echo '$debug_packages' | xargs sudo pacman -Rdd --noconfirm" || true
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Remove debug packages" >> "$DOTFILES_LOG_FILE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: No debug packages to remove" >> "$DOTFILES_LOG_FILE"
    fi

    # Resolve AUR vs official package conflicts before updating
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Resolve package conflicts" >> "$DOTFILES_LOG_FILE"
    local conflicts_found=()
    {
        # Capture conflicts list from the operation
        local conflicts_output=$(mktemp)

        # Get all AUR packages
        local aur_packages=($(pacman -Qmq 2>/dev/null || true))

        if [[ ${#aur_packages[@]} -eq 0 ]]; then
            rm -f "$conflicts_output"
        else
            # Sync package database
            run_command_logged "Sync package database" sudo pacman -Sy --noconfirm

            local conflicts_to_remove=()
            for aur_pkg in "${aur_packages[@]}"; do
                local base_name="${aur_pkg%-git}"
                base_name="${base_name%-bin}"
                [[ "$aur_pkg" == "$base_name" ]] && continue

                if pacman -Si "$base_name" &>/dev/null; then
                    local aur_conflicts=$(pacman -Qi "$aur_pkg" 2>/dev/null | grep "Conflicts With" | cut -d: -f2 | xargs)
                    if [[ "$aur_conflicts" == *"$base_name"* ]]; then
                        conflicts_to_remove+=("$aur_pkg")
                    fi
                fi
            done

            if [[ ${#conflicts_to_remove[@]} -gt 0 ]]; then
                printf "%s\n" "${conflicts_to_remove[@]}" > "$conflicts_output"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Found conflicts: ${conflicts_to_remove[*]}" >> "$DOTFILES_LOG_FILE"

                if ! run_command_logged "Remove conflicting packages" sudo pacman -Rdd --noconfirm "${conflicts_to_remove[@]}"; then
                    rm -f "$conflicts_output"
                    finish_logging
                    sleep 1
                    stop_log_monitor
                    log_error "Failed to resolve package conflicts. Update cannot proceed."
                    return 1
                fi
            else
                rm -f "$conflicts_output"
            fi
        fi

        # Read conflicts from temp file
        if [[ -f "$conflicts_output" && -s "$conflicts_output" ]]; then
            readarray -t conflicts_found < "$conflicts_output"
            rm -f "$conflicts_output"

            # Clean up package files (silent)
            if [[ ${#conflicts_found[@]} -gt 0 ]]; then
                # Remove from AUR packages file
                if [[ -f "$AUR_PACKAGES_FILE" ]]; then
                    local temp_file=$(mktemp)
                    while IFS= read -r line; do
                        local should_keep=true
                        for pkg in "${conflicts_found[@]}"; do
                            [[ "$line" == "$pkg" ]] && { should_keep=false; break; }
                        done
                        $should_keep && echo "$line" >> "$temp_file"
                    done < "$AUR_PACKAGES_FILE"
                    [[ -s "$temp_file" ]] && mv "$temp_file" "$AUR_PACKAGES_FILE" || rm -f "$temp_file"
                fi

                # Add base packages to official packages file
                if [[ -f "$PACKAGES_FILE" ]]; then
                    local temp_file=$(mktemp)
                    cp "$PACKAGES_FILE" "$temp_file"
                    for aur_pkg in "${conflicts_found[@]}"; do
                        local base_name="${aur_pkg%-git}"
                        base_name="${base_name%-bin}"
                        if pacman -Si "$base_name" &>/dev/null; then
                            grep -qxF "$base_name" "$temp_file" 2>/dev/null || echo "$base_name" >> "$temp_file"
                        fi
                    done
                    sort -u "$temp_file" -o "$temp_file"
                    mv "$temp_file" "$PACKAGES_FILE"
                fi
            fi
        else
            rm -f "$conflicts_output"
        fi
    }
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Resolve package conflicts" >> "$DOTFILES_LOG_FILE"

    # Update official repositories
    if ! run_command_logged "Update official packages" sudo pacman -Syu --noconfirm; then
        finish_logging
        sleep 1
        stop_log_monitor
        log_error "pacman repo update failed"
        return 1
    fi

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

    # Update AUR packages
    if ! run_command_logged "Update AUR packages" yay -Sua --noconfirm --answerclean N --answerdiff N; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Retrying: Update AUR packages" >> "$DOTFILES_LOG_FILE"
        run_command_logged "Update AUR packages (retry)" yay -Sua --noconfirm --answerclean N --answerdiff N
    fi
    local aur_exit=$?

    # Restore ~/.npmrc if we moved it
    if [[ -n "$npmrc_backup" && -f "$npmrc_backup" ]]; then
        mv "$npmrc_backup" "$HOME/.npmrc" 2>/dev/null || true
    fi

    if [[ $aur_exit -ne 0 ]]; then
        finish_logging
        sleep 1
        stop_log_monitor
        log_error "AUR update failed (exit code: $aur_exit)"
        log_info "Try running: yay -Sua --debug to see detailed error"
        return 1
    fi

    finish_logging
    sleep 1
    stop_log_monitor true

    log_success "System update complete"
}
