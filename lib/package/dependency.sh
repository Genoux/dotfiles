#!/bin/bash
# Package dependency resolution

DEPENDENCIES_FILE="$DOTFILES_DIR/packages/dependencies.json"

# Load dependency definitions
load_dependencies() {
    if [[ ! -f "$DEPENDENCIES_FILE" ]]; then
        log_warning "Dependency file not found: $DEPENDENCIES_FILE"
        return 1
    fi

    if ! jq empty "$DEPENDENCIES_FILE" 2>/dev/null; then
        log_error "Invalid dependency file"
        return 1
    fi

    return 0
}

# Get installation groups in priority order
get_install_groups() {
    if ! load_dependencies; then
        return 1
    fi

    jq -r '.groups | to_entries | sort_by(.value.priority) | .[].key' "$DEPENDENCIES_FILE"
}

# Get packages for a group
get_group_packages() {
    local group="$1"

    if ! load_dependencies; then
        return 1
    fi

    jq -r ".groups.\"$group\".packages[]" "$DEPENDENCIES_FILE" 2>/dev/null
}

# Check if package is in a group
is_in_group() {
    local package="$1"
    local group="$2"

    if ! load_dependencies; then
        return 1
    fi

    jq -e ".groups.\"$group\".packages | index(\"$package\")" "$DEPENDENCIES_FILE" >/dev/null 2>&1
}

# Get group for package
get_package_group() {
    local package="$1"

    if ! load_dependencies; then
        echo "applications"  # default
        return
    fi

    local group
    group=$(jq -r --arg pkg "$package" '
        .groups | to_entries[] |
        select(.value.packages | index($pkg)) |
        .key
    ' "$DEPENDENCIES_FILE" | head -1)

    if [[ -z "$group" ]]; then
        echo "applications"  # default group for ungrouped packages
    else
        echo "$group"
    fi
}

# Check if package is critical
is_critical_package() {
    local package="$1"

    if ! load_dependencies; then
        return 1
    fi

    jq -e ".critical_packages | index(\"$package\")" "$DEPENDENCIES_FILE" >/dev/null 2>&1
}

# Sort packages by dependency order
sort_packages_by_dependency() {
    local -n packages_ref=$1

    if ! load_dependencies; then
        # No sorting if dependencies unavailable
        return
    fi

    # Group packages
    declare -A grouped_packages
    local ungrouped=()

    for pkg in "${packages_ref[@]}"; do
        local group
        group=$(get_package_group "$pkg")

        if [[ -z "${grouped_packages[$group]}" ]]; then
            grouped_packages[$group]="$pkg"
        else
            grouped_packages[$group]="${grouped_packages[$group]} $pkg"
        fi
    done

    # Rebuild array in priority order
    packages_ref=()
    while IFS= read -r group; do
        if [[ -n "${grouped_packages[$group]}" ]]; then
            for pkg in ${grouped_packages[$group]}; do
                packages_ref+=("$pkg")
            done
        fi
    done < <(get_install_groups)
}

# Verify critical packages installed
verify_critical_packages() {
    if ! load_dependencies; then
        log_warning "Cannot verify critical packages (dependency file not found)"
        return 0
    fi

    local missing_critical=()

    while IFS= read -r pkg; do
        if ! pacman -Qq "$pkg" &>/dev/null && ! command -v "$pkg" &>/dev/null; then
            missing_critical+=("$pkg")
        fi
    done < <(jq -r '.critical_packages[]' "$DEPENDENCIES_FILE")

    if [[ ${#missing_critical[@]} -gt 0 ]]; then
        log_error "Critical packages missing:"
        printf '  ✗ %s\n' "${missing_critical[@]}"
        return 1
    fi

    log_success "✓ All critical packages installed"
    return 0
}

# Install packages in dependency order
install_packages_ordered() {
    local -n packages_ref=$1
    local type="${2:-official}"

    log_info "Sorting packages by dependency order..."
    sort_packages_by_dependency packages_ref

    log_info "Installing packages in groups..."

    # Track what we've installed
    local installed=()
    local failed=()

    # Get unique groups from package list
    declare -A package_groups
    for pkg in "${packages_ref[@]}"; do
        local group
        group=$(get_package_group "$pkg")
        package_groups[$group]=1
    done

    # Install group by group
    for group in $(get_install_groups); do
        if [[ -z "${package_groups[$group]}" ]]; then
            continue
        fi

        local group_packages=()
        for pkg in "${packages_ref[@]}"; do
            local pkg_group
            pkg_group=$(get_package_group "$pkg")
            if [[ "$pkg_group" == "$group" ]]; then
                group_packages+=("$pkg")
            fi
        done

        if [[ ${#group_packages[@]} -eq 0 ]]; then
            continue
        fi

        log_section "Installing $group group (${#group_packages[@]} packages)"

        if [[ "$type" == "official" ]]; then
            install_official_packages group_packages
        else
            install_aur_packages group_packages
        fi

        local group_exit=$?

        # Track installed
        for pkg in "${group_packages[@]}"; do
            if pacman -Qq "$pkg" &>/dev/null; then
                installed+=("$pkg")
            else
                failed+=("$pkg")
            fi
        done

        echo

        # Stop if critical packages failed
        for pkg in "${failed[@]}"; do
            if is_critical_package "$pkg"; then
                log_error "Critical package failed: $pkg"
                log_error "Cannot continue installation"
                return 1
            fi
        done
    done

    log_info "Installation summary:"
    log_success "  ✓ Installed: ${#installed[@]} packages"

    if [[ ${#failed[@]} -gt 0 ]]; then
        log_warning "  ✗ Failed: ${#failed[@]} packages"
        return 1
    fi

    return 0
}
