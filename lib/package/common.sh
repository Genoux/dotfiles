#!/bin/bash
# Common package management utilities
# Extracted functions used across multiple package scripts

# Check what packages require a given package
# Returns: space-separated list of packages, or "None"
check_package_dependencies() {
    local pkg="$1"
    pacman -Qi "$pkg" 2>/dev/null | grep "^Required By" | cut -d: -f2 | xargs
}

# Check if a package is explicitly installed (not a dependency)
is_explicitly_installed() {
    local pkg="$1"
    local install_reason=$(pacman -Qi "$pkg" 2>/dev/null | grep "^Install Reason" | cut -d: -f2 | xargs)
    [[ "$install_reason" == "Explicitly installed" ]]
}

# Check if a package is from AUR
is_aur_package() {
    local pkg="$1"
    pacman -Qm "$pkg" &>/dev/null
}

# Check if a package is installed
is_package_installed() {
    local pkg="$1"
    pacman -Qq "$pkg" &>/dev/null
}

# Get packages that are safe to remove (not required by others)
# Input: array of package names (passed by reference)
# Output: prints safe packages to stdout, one per line
get_safe_to_remove() {
    local -n packages_ref=$1
    local safe=()
    local blocked=()

    for pkg in "${packages_ref[@]}"; do
        local required_by=$(check_package_dependencies "$pkg")

        if [[ -z "$required_by" || "$required_by" == "None" ]]; then
            safe+=("$pkg")
        else
            blocked+=("$pkg (required by: $required_by)")
        fi
    done

    # Report blocked packages if any
    if [[ ${#blocked[@]} -gt 0 ]]; then
        log_info "Packages blocked (required by other packages):"
        printf '  - %s\n' "${blocked[@]}"
        echo
    fi

    # Return safe packages
    printf '%s\n' "${safe[@]}"
}

# Build package lists from dotfiles with hardware filtering
# Populates global arrays: dotfiles_official, dotfiles_aur, dotfiles_official_map, dotfiles_aur_map
read_dotfiles_packages() {
    dotfiles_official=()
    dotfiles_aur=()
    declare -gA dotfiles_official_map=()
    declare -gA dotfiles_aur_map=()

    # Read official packages with hardware filtering
    if [[ -f "$PACKAGES_FILE" ]]; then
        local filtered_packages=$(filter_packages_by_hardware "$PACKAGES_FILE")
        while IFS= read -r pkg; do
            if [[ -n "$pkg" && ! "$pkg" =~ ^# ]]; then
                dotfiles_official+=("$pkg")
                dotfiles_official_map["$pkg"]=1
            fi
        done < "$filtered_packages"
        rm -f "$filtered_packages"
    fi

    # Read AUR packages (no hardware filtering needed for AUR)
    if [[ -f "$AUR_PACKAGES_FILE" ]]; then
        while IFS= read -r pkg; do
            if [[ -n "$pkg" && ! "$pkg" =~ ^# ]]; then
                dotfiles_aur+=("$pkg")
                dotfiles_aur_map["$pkg"]=1
            fi
        done < "$AUR_PACKAGES_FILE"
    fi
}

# Build package lists from installed system packages
# Populates global arrays: installed_official, installed_aur, installed_official_map, installed_aur_map
read_installed_packages() {
    # Get all installed packages
    local -A all_installed=()
    while IFS= read -r pkg; do
        all_installed["$pkg"]=1
    done < <(pacman -Qq 2>/dev/null)

    # Get AUR package set
    local -A aur_packages_set=()
    while IFS= read -r pkg; do
        aur_packages_set["$pkg"]=1
    done < <(pacman -Qmq 2>/dev/null)

    # Categorize explicitly installed packages
    installed_official=()
    installed_aur=()
    declare -gA installed_official_map=()
    declare -gA installed_aur_map=()

    while IFS= read -r pkg; do
        if [[ -v aur_packages_set["$pkg"] ]]; then
            installed_aur+=("$pkg")
            installed_aur_map["$pkg"]=1
        else
            installed_official+=("$pkg")
            installed_official_map["$pkg"]=1
        fi
    done < <(pacman -Qeq 2>/dev/null)
}

# Find packages in dotfiles that are not installed
# Requires: read_dotfiles_packages() and read_installed_packages() called first
# Output: sets global arrays missing_official and missing_aur
find_missing_packages() {
    local -A all_installed=()
    while IFS= read -r pkg; do
        all_installed["$pkg"]=1
    done < <(pacman -Qq 2>/dev/null)

    missing_official=()
    missing_aur=()

    for pkg in "${dotfiles_official[@]}"; do
        if [[ ! -v all_installed["$pkg"] ]]; then
            missing_official+=("$pkg")
        fi
    done

    for pkg in "${dotfiles_aur[@]}"; do
        if [[ ! -v all_installed["$pkg"] ]]; then
            missing_aur+=("$pkg")
        fi
    done
}

# Find packages installed but not in dotfiles
# Requires: read_dotfiles_packages() and read_installed_packages() called first
# Output: sets global arrays extra_official and extra_aur
find_extra_packages() {
    extra_official=()
    extra_aur=()

    for pkg in "${installed_official[@]}"; do
        if [[ ! -v dotfiles_official_map["$pkg"] ]]; then
            extra_official+=("$pkg")
        fi
    done

    for pkg in "${installed_aur[@]}"; do
        if [[ ! -v dotfiles_aur_map["$pkg"] ]]; then
            extra_aur+=("$pkg")
        fi
    done
}

# Categorize extra packages into dependencies and truly extra
# Requires: find_extra_packages() called first, dotfiles_official_map and dotfiles_aur_map populated
# Output: sets global arrays extra_as_deps_official, extra_as_deps_aur, extra_not_deps
categorize_extra_packages() {
    extra_as_deps_official=()
    extra_as_deps_aur=()
    extra_not_deps=()

    # Build dotfiles map for dependency checking
    local -A dotfiles_map
    for pkg in "${dotfiles_official[@]}" "${dotfiles_aur[@]}"; do
        dotfiles_map[$pkg]=1
    done

    # Get all dependency info in one batch call
    local -A package_dependencies=()
    if [[ ${#extra_official[@]} -gt 0 || ${#extra_aur[@]} -gt 0 ]]; then
        while IFS='|' read -r pkg required_by; do
            package_dependencies["$pkg"]="$required_by"
        done < <(pacman -Qi "${extra_official[@]}" "${extra_aur[@]}" 2>/dev/null | \
                 awk '/^Name/ {name=$3} /^Required By/ {gsub(/^Required By *: */, ""); print name"|"$0}')
    fi

    # Categorize based on whether they're dependencies of dotfiles packages
    local -A aur_packages_set=()
    while IFS= read -r pkg; do
        aur_packages_set["$pkg"]=1
    done < <(pacman -Qmq 2>/dev/null)

    for pkg in "${extra_official[@]}" "${extra_aur[@]}"; do
        local required_by="${package_dependencies[$pkg]}"
        local is_dependency=false

        if [[ -n "$required_by" && "$required_by" != "None" ]]; then
            for req in $required_by; do
                if [[ -n "${dotfiles_map[$req]}" ]]; then
                    is_dependency=true
                    break
                fi
            done
        fi

        if $is_dependency; then
            if [[ -v aur_packages_set["$pkg"] ]]; then
                extra_as_deps_aur+=("$pkg")
            else
                extra_as_deps_official+=("$pkg")
            fi
        else
            extra_not_deps+=("$pkg")
        fi
    done
}

# Add packages to dotfiles lists
# Args: package names (official and AUR mixed)
add_packages_to_dotfiles() {
    local packages=("$@")

    for pkg in "${packages[@]}"; do
        if is_aur_package "$pkg"; then
            if ! grep -Fxq "$pkg" "$AUR_PACKAGES_FILE" 2>/dev/null; then
                echo "$pkg" >> "$AUR_PACKAGES_FILE"
            fi
        else
            if ! grep -Fxq "$pkg" "$PACKAGES_FILE" 2>/dev/null; then
                echo "$pkg" >> "$PACKAGES_FILE"
            fi
        fi
    done

    # Sort and deduplicate
    sort -u "$PACKAGES_FILE" -o "$PACKAGES_FILE"
    sort -u "$AUR_PACKAGES_FILE" -o "$AUR_PACKAGES_FILE"
}

# Remove packages from dotfiles lists
# Args: package names (will be removed from both files)
remove_packages_from_dotfiles() {
    local packages=("$@")

    for pkg in "${packages[@]}"; do
        # Escape special characters for sed
        local escaped_pkg=$(printf '%s\n' "$pkg" | sed 's/[.[\*^$/]/\\&/g')
        sed -i "/^${escaped_pkg}$/d" "$PACKAGES_FILE"
        sed -i "/^${escaped_pkg}$/d" "$AUR_PACKAGES_FILE"
    done
}
