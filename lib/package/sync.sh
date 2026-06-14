#!/bin/bash
# Package list synchronization (DEPRECATED - use packages_manage instead)

packages_sync() {
    log_section "Syncing Package Lists"

    log_info "Scanning installed packages..."

    # Get all explicitly installed packages and categorize them
    local aur_packages_temp=$(mktemp)
    local official_temp=$(mktemp)

    # Get official packages (explicitly installed, not from AUR)
    pacman -Qeq | grep -vf <(pacman -Qmq) >> "$official_temp"

    # Get AUR packages
    pacman -Qmq >> "$aur_packages_temp"

    # Sort the files
    sort "$aur_packages_temp" -o "$aur_packages_temp"
    sort "$official_temp" -o "$official_temp"

    # Show changes
    local official_changes=false
    local aur_changes=false

    if [[ -f "$PACKAGES_FILE" ]]; then
        if ! diff -q "$official_temp" "$PACKAGES_FILE" &>/dev/null; then
            official_changes=true
            log_info "Changes detected in official packages:"
            diff --color=auto "$PACKAGES_FILE" "$official_temp" | grep "^[<>]" || true
        fi
    else
        official_changes=true
    fi

    if [[ -f "$AUR_PACKAGES_FILE" ]]; then
        if ! diff -q "$aur_packages_temp" "$AUR_PACKAGES_FILE" &>/dev/null; then
            aur_changes=true
            log_info "Changes detected in AUR packages:"
            diff --color=auto "$AUR_PACKAGES_FILE" "$aur_packages_temp" | grep "^[<>]" || true
        fi
    else
        aur_changes=true
    fi

    echo

    # Update files if changes detected
    if $official_changes || $aur_changes; then
        cp "$official_temp" "$PACKAGES_FILE"
        cp "$aur_packages_temp" "$AUR_PACKAGES_FILE"

        log_success "Package lists updated"
        show_info "Official packages" "$(wc -l < "$PACKAGES_FILE")"
        show_info "AUR packages" "$(wc -l < "$AUR_PACKAGES_FILE")"
    else
        log_success "Package lists are already up to date"
    fi

    # Cleanup
    rm -f "$official_temp" "$aur_packages_temp"
}
