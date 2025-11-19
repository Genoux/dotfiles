#!/bin/bash
# Package status display

packages_status() {
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

    # Find missing packages (in lists but not installed)
    local -a missing_official=()
    local -a missing_aur=()

    for pkg in "${official_packages[@]}"; do
        [[ -z "$pkg" ]] && continue
        if ! pacman -Qi "$pkg" &>/dev/null; then
            missing_official+=("$pkg")
        fi
    done

    for pkg in "${aur_packages[@]}"; do
        [[ -z "$pkg" ]] && continue
        if ! pacman -Qi "$pkg" &>/dev/null; then
            missing_aur+=("$pkg")
        fi
    done

    # Show missing packages
    if [[ ${#missing_official[@]} -gt 0 ]] || [[ ${#missing_aur[@]} -gt 0 ]]; then
        log_info "Missing packages (in dotfiles but not installed):"
        if [[ ${#missing_official[@]} -gt 0 ]]; then
            for pkg in "${missing_official[@]}"; do
                echo "  $(gum style --foreground 3 "○ $pkg") (official)"
            done
        fi
        if [[ ${#missing_aur[@]} -gt 0 ]]; then
            for pkg in "${missing_aur[@]}"; do
                echo "  $(gum style --foreground 3 "○ $pkg") (AUR)"
            done
        fi
        echo
    else
        log_success "All tracked packages are installed"
        echo
    fi

    # Check for outdated packages
    if command -v yay &>/dev/null; then
        local outdated_packages=$(yay -Qu 2>/dev/null)
        if [[ -n "$outdated_packages" ]]; then
            local outdated_count=$(echo "$outdated_packages" | wc -l)
            log_info "Packages with available updates ($outdated_count):"
            echo "$outdated_packages" | while IFS= read -r line; do
                local pkg_name=$(echo "$line" | awk '{print $1}')
                echo "  $(gum style --foreground 3 "○ $pkg_name")"
            done
            echo
        else
            log_success "All packages are up to date"
            echo
        fi
    fi

    # Find orphaned packages (installed but not in dotfiles lists)
    local -a all_tracked=("${official_packages[@]}" "${aur_packages[@]}")
    local -a orphaned=()

    # Get all explicitly installed packages
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        local pkg_name=$(echo "$pkg" | cut -d' ' -f1)

        # Check if it's in our tracked lists
        local found=false
        for tracked in "${all_tracked[@]}"; do
            if [[ "$tracked" == "$pkg_name" ]]; then
                found=true
                break
            fi
        done

        if [[ "$found" == "false" ]]; then
            orphaned+=("$pkg_name")
        fi
    done < <(pacman -Qe 2>/dev/null)

    # Show orphaned packages (limit to first 20 to avoid overwhelming output)
    if [[ ${#orphaned[@]} -gt 0 ]]; then
        log_warning "Orphaned packages (installed but not in dotfiles):"
        local display_count=${#orphaned[@]}
        [[ $display_count -gt 20 ]] && display_count=20

        for ((i=0; i<display_count; i++)); do
            echo "  $(gum style --foreground 8 "○ ${orphaned[$i]}")"
        done

        if [[ ${#orphaned[@]} -gt 20 ]]; then
            echo "  $(gum style --foreground 8 "... and $(( ${#orphaned[@]} - 20 )) more")"
        fi
        echo
    fi
}
