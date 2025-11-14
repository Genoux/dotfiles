#!/bin/bash
# Package status display

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
