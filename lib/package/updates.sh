#!/bin/bash
# Package updates checker

packages_updates() {
    log_section "Package Updates"

    # Check for updates with spinner
    gum spin --spinner dot --title "Checking for package updates..." -- yay -Qu > /tmp/package-updates.tmp 2>/dev/null

    if [[ ! -s /tmp/package-updates.tmp ]]; then
        log_success "All packages are up to date!"
        rm -f /tmp/package-updates.tmp
        return
    fi

    # Separate official and AUR packages
    local -a official_updates=()
    local -a aur_updates=()

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local pkg_name=$(echo "$line" | awk '{print $1}')

        if pacman -Qm "$pkg_name" &>/dev/null 2>&1; then
            aur_updates+=("$line")
        else
            official_updates+=("$line")
        fi
    done < /tmp/package-updates.tmp

    rm -f /tmp/package-updates.tmp

    # Display official updates
    if [[ ${#official_updates[@]} -gt 0 ]]; then
        log_info "Official Repositories (${#official_updates[@]} updates):"
        echo
        for line in "${official_updates[@]}"; do
            local pkg=$(echo "$line" | awk '{print $1}')
            local old_ver=$(echo "$line" | awk '{print $2}')
            local new_ver=$(echo "$line" | awk '{print $4}')
            echo "  $(status_neutral) $pkg: $(gum style --foreground 8 "$old_ver") → $(gum style --foreground 10 "$new_ver")"
        done
        echo
    fi

    # Display AUR updates
    if [[ ${#aur_updates[@]} -gt 0 ]]; then
        log_info "AUR (${#aur_updates[@]} updates):"
        echo
        for line in "${aur_updates[@]}"; do
            local pkg=$(echo "$line" | awk '{print $1}')
            local old_ver=$(echo "$line" | awk '{print $2}')
            local new_ver=$(echo "$line" | awk '{print $4}')
            echo "  $(status_neutral) $pkg: $(gum style --foreground 8 "$old_ver") → $(gum style --foreground 10 "$new_ver")"
        done
        echo
    fi

    # Summary
    local total=$((${#official_updates[@]} + ${#aur_updates[@]}))
    log_info "Total: $total package$([ $total -ne 1 ] && echo "s") with available updates"
    echo

    # Ask if user wants to update
    if gum confirm "Update all packages now?"; then
        log_info "Updating packages..."
        yay -Syu --noconfirm
    fi
}
