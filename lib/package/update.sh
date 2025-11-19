#!/bin/bash
# System package updates and conflict resolution
# Requires: gum (charmbracelet/gum)

# Update system packages
packages_update() {
    log_section "Updating System"

    # Validate sudo access upfront
    log_info "Validating sudo access..."
    echo
    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges"
        return 1
    fi

    clear

    log_section "Updating System"

    # Remove debug packages first (silent if none found)
    local debug_packages=$(pacman -Qq | grep '\-debug$' 2>/dev/null || true)
    if [[ -n "$debug_packages" ]]; then
        echo "$debug_packages" | xargs sudo pacman -Rdd --noconfirm >/dev/null 2>&1 || true
    fi

    # Resolve AUR vs official package conflicts before updating
    local conflicts_found=()
    {
        # Capture conflicts list from the spinner operation
        local conflicts_output=$(mktemp)
        run_with_spinner "Checking for package conflicts..." bash -c "
            # Inline conflict checking to avoid function export issues
            aur_packages=(\$(pacman -Qmq 2>/dev/null || true))
            [[ \${#aur_packages[@]} -eq 0 ]] && exit 0

            sudo pacman -Sy --noconfirm > /dev/null 2>&1 || true

            conflicts_to_remove=()
            for aur_pkg in \"\${aur_packages[@]}\"; do
                base_name=\"\${aur_pkg%-git}\"
                base_name=\"\${base_name%-bin}\"
                [[ \"\$aur_pkg\" == \"\$base_name\" ]] && continue

                if pacman -Si \"\$base_name\" &>/dev/null; then
                    aur_conflicts=\$(pacman -Qi \"\$aur_pkg\" 2>/dev/null | grep \"Conflicts With\" | cut -d: -f2 | xargs)
                    if [[ \"\$aur_conflicts\" == *\"\$base_name\"* ]]; then
                        conflicts_to_remove+=(\"\$aur_pkg\")
                    fi
                fi
            done

            [[ \${#conflicts_to_remove[@]} -eq 0 ]] && exit 0

            # Output conflicts to temp file for later processing
            printf \"%s\\n\" \"\${conflicts_to_remove[@]}\" > \"$conflicts_output\"

            # Remove conflicts
            sudo pacman -Rdd --noconfirm \"\${conflicts_to_remove[@]}\" > /dev/null 2>&1 || exit 1
        " || {
            rm -f "$conflicts_output"
            log_error "Failed to resolve package conflicts. Update cannot proceed."
            return 1
        }

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

                log_success "Resolved ${#conflicts_found[@]} package conflict(s)"
                echo
            fi
        else
            rm -f "$conflicts_output"
        fi
    }

    # Update official repositories first with spinner
    run_with_spinner "Updating official repositories..." \
        bash -c 'sudo pacman -Syu --noconfirm > /dev/null 2>&1'
    local pacman_exit=$?

    if [[ $pacman_exit -eq 0 ]]; then
        log_success "Official repositories updated"
    else
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

    local aur_exit=0

    # Update AUR packages with spinner
    run_with_spinner "Updating AUR packages..." \
        bash -c 'yay -Sua --noconfirm --answerclean N --answerdiff N > /dev/null 2>&1' || aur_exit=$?

    if [[ $aur_exit -ne 0 ]]; then
        log_warning "AUR update failed (exit $aur_exit) - retrying..."
        aur_exit=0
        run_with_spinner "Retrying AUR update..." \
            bash -c 'yay -Sua --noconfirm --answerclean N --answerdiff N > /dev/null 2>&1' || aur_exit=$?
    fi

    if [[ $aur_exit -eq 0 ]]; then
        log_success "AUR packages updated"
    fi
    echo

    # Restore ~/.npmrc if we moved it
    if [[ -n "$npmrc_backup" && -f "$npmrc_backup" ]]; then
        mv "$npmrc_backup" "$HOME/.npmrc" 2>/dev/null || true
    fi

    if [[ $aur_exit -eq 0 ]]; then
        log_success "System update complete"
        return 0
    else
        log_error "AUR update failed (exit code: $aur_exit)"
        log_info "Try running: yay -Sua --debug to see detailed error"
        return 1
    fi
}
