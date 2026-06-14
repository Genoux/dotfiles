#!/bin/bash
# Post-install package audit helpers

package_install_audit() {
    local -n packages_ref=$1
    local -n aur_packages_ref=$2

    local explicit_count
    explicit_count=$(pacman -Qeq | wc -l)

    if [[ $explicit_count -le 500 ]]; then
        local deps_to_add_official=()
        local deps_to_add_aur=()
        declare -A dotfiles_map

        for pkg in "${packages_ref[@]}" "${aur_packages_ref[@]}"; do
            dotfiles_map[$pkg]=1
        done

        while IFS= read -r installed_pkg; do
            [[ -n "${dotfiles_map[$installed_pkg]}" ]] && continue

            local required_by
            required_by=$(pacman -Qi "$installed_pkg" 2>/dev/null | awk '/^Required By/ {for(i=4;i<=NF;i++) print $i}')

            if [[ -n "$required_by" ]]; then
                local should_add=false

                while read -r req; do
                    if [[ -n "${dotfiles_map[$req]}" ]]; then
                        should_add=true
                        break
                    fi
                done <<< "$required_by"

                if $should_add; then
                    if pacman -Qm "$installed_pkg" &>/dev/null; then
                        deps_to_add_aur+=("$installed_pkg")
                    else
                        deps_to_add_official+=("$installed_pkg")
                    fi
                fi
            fi
        done < <(pacman -Qeq)

        if [[ ${#deps_to_add_official[@]} -gt 0 || ${#deps_to_add_aur[@]} -gt 0 ]]; then
            log_info "Found dependencies to add to dotfiles:"
            [[ ${#deps_to_add_official[@]} -gt 0 ]] && printf '  - %s (official)\n' "${deps_to_add_official[@]}"
            [[ ${#deps_to_add_aur[@]} -gt 0 ]] && printf '  - %s (aur)\n' "${deps_to_add_aur[@]}"
            echo

            for dep in "${deps_to_add_official[@]}"; do
                echo "$dep" >> "$PACKAGES_FILE"
            done

            for dep in "${deps_to_add_aur[@]}"; do
                echo "$dep" >> "$AUR_PACKAGES_FILE"
            done

            sort -u "$PACKAGES_FILE" -o "$PACKAGES_FILE"
            sort -u "$AUR_PACKAGES_FILE" -o "$AUR_PACKAGES_FILE"
        fi
    fi

    local outdated_official
    outdated_official=$(pacman -Qu 2>/dev/null | grep -v "\[ignored\]" | wc -l)

    local outdated_aur=0
    if command -v yay &>/dev/null; then
        outdated_aur=$(yay -Qua 2>/dev/null | wc -l)
    fi

    if [[ $outdated_official -gt 0 || $outdated_aur -gt 0 ]]; then
        echo
        log_warning "Found $outdated_official official + $outdated_aur AUR packages with updates available"
        log_info "Run 'yay -Syu' or use the update menu option to upgrade"
        echo
    fi
}
