#!/bin/bash
# Package status display

packages_status() {
    local updates_only="${1:-}"
    
    # If called from System Status, show brief updates summary
    if [[ "$updates_only" == "--updates-only" ]]; then

        # Check for outdated packages
        if command -v yay &>/dev/null; then
            local outdated_packages=$(yay -Qu 2>/dev/null)
            if [[ -n "$outdated_packages" ]]; then
                local outdated_count=$(echo "$outdated_packages" | wc -l)

                # Count official vs AUR
                local official_count=0
                local aur_count=0
                while IFS= read -r line; do
                    [[ -z "$line" ]] && continue
                    local pkg_name=$(echo "$line" | awk '{print $1}')
                    if pacman -Qm "$pkg_name" &>/dev/null; then
                        ((aur_count++))
                    else
                        ((official_count++))
                    fi
                done <<< "$outdated_packages"

                log_info "Packages with available updates ($outdated_count: $official_count official, $aur_count AUR)"
                echo
            else
                log_info "All packages are up to date"
                echo
            fi
        fi
        return
    fi

    log_section "Package Status"

    # Get package lists
    local -a official_packages=()
    local -a aur_packages=()

    if [[ -f "$PACKAGES_FILE" ]]; then
        readarray -t official_packages < <(grep -vE '^#|^$' "$PACKAGES_FILE")
    fi

    if [[ -f "$AUR_PACKAGES_FILE" ]]; then
        readarray -t aur_packages < <(grep -vE '^#|^$' "$AUR_PACKAGES_FILE")
    fi

    # Get all installed packages in one call
    local -A installed_packages=()
    while IFS= read -r pkg; do
        installed_packages["$pkg"]=1
    done < <(pacman -Qq 2>/dev/null)

    # Count installed packages
    local installed_official=0
    local installed_aur=0
    for pkg in "${official_packages[@]}"; do
        [[ -z "$pkg" ]] && continue
        [[ -v installed_packages["$pkg"] ]] && ((installed_official++))
    done
    for pkg in "${aur_packages[@]}"; do
        [[ -z "$pkg" ]] && continue
        [[ -v installed_packages["$pkg"] ]] && ((installed_aur++))
    done

    # Find missing packages (in dotfiles but not installed)
    local missing_official=0
    local missing_aur=0
    for pkg in "${official_packages[@]}"; do
        [[ -z "$pkg" ]] && continue
        [[ ! -v installed_packages["$pkg"] ]] && ((missing_official++))
    done
    for pkg in "${aur_packages[@]}"; do
        [[ -z "$pkg" ]] && continue
        [[ ! -v installed_packages["$pkg"] ]] && ((missing_aur++))
    done

    # Count updates available
    local updates_official=0
    local updates_aur=0
    if command -v yay &>/dev/null; then
        local outdated_packages=$(yay -Qu 2>/dev/null)
        if [[ -n "$outdated_packages" ]]; then
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                local pkg_name=$(echo "$line" | awk '{print $1}')
                if pacman -Qm "$pkg_name" &>/dev/null; then
                    ((updates_aur++))
                else
                    ((updates_official++))
                fi
            done <<< "$outdated_packages"
        fi
    fi

    # Find orphaned packages (installed but not in dotfiles)
    local -A tracked_packages=()
    for pkg in "${official_packages[@]}" "${aur_packages[@]}"; do
        [[ -n "$pkg" ]] && tracked_packages["$pkg"]=1
    done

    local orphaned_count=0
    while IFS= read -r pkg_name; do
        [[ -z "$pkg_name" ]] && continue
        [[ ! -v tracked_packages["$pkg_name"] ]] && ((orphaned_count++))
    done < <(pacman -Qeq 2>/dev/null)

    # Display summary
    log_info "Tracked Packages:"
    echo "  Official: $installed_official packages"
    echo "  AUR:      $installed_aur packages"
    echo

    if [[ $missing_official -gt 0 ]] || [[ $missing_aur -gt 0 ]]; then
        log_warning "Missing (in dotfiles but not installed):"
        [[ $missing_official -gt 0 ]] && echo "  Official: $missing_official packages"
        [[ $missing_aur -gt 0 ]] && echo "  AUR:      $missing_aur packages"
        echo
    fi

    if [[ $updates_official -gt 0 ]] || [[ $updates_aur -gt 0 ]]; then
        log_info "Updates Available:"
        [[ $updates_official -gt 0 ]] && echo "  Official: $updates_official packages"
        [[ $updates_aur -gt 0 ]] && echo "  AUR:      $updates_aur packages"
        echo
    fi

    if [[ $orphaned_count -gt 0 ]]; then
        log_warning "Orphaned (installed but not in dotfiles): $orphaned_count packages"
        echo
    fi
}
