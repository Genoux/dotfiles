#!/bin/bash
# Pre-flight checks for installation

# Check network connectivity
check_network() {
    log_info "Checking network connectivity..."

    if ! ping -c 1 archlinux.org &>/dev/null; then
        log_error "No network connectivity to archlinux.org"
        return 1
    fi

    if ! ping -c 1 aur.archlinux.org &>/dev/null; then
        log_warning "Cannot reach AUR (aur.archlinux.org)"
        log_info "AUR packages may fail to install"
    fi

    log_success "✓ Network connectivity OK"
    return 0
}

# Check disk space (auto-reclaims the package cache when low before failing)
check_disk_space() {
    log_info "Checking disk space..."

    local required_mb=5000  # 5GB minimum
    local cache_dir="/var/cache/pacman/pkg"
    local available_mb
    available_mb=$(df "$cache_dir" --output=avail -BM | tail -1 | tr -dc '0-9')

    # A clean install re-downloads packages into the pacman cache, which sits on
    # root. On a tight root that cache is the difference between pass and fail, so
    # reclaim it automatically and re-check before giving up. Cached .pkg files are
    # just downloads — removing them only means future installs re-fetch.
    if [[ ${available_mb:-0} -lt $required_mb ]]; then
        log_warning "Low disk space (${available_mb}M) — clearing package cache to reclaim..."
        sudo rm -rf "$cache_dir"/download-* 2>/dev/null || true
        sudo find "$cache_dir" -maxdepth 1 -type f -name '*.pkg.tar*' -delete 2>/dev/null || true
        available_mb=$(df "$cache_dir" --output=avail -BM | tail -1 | tr -dc '0-9')
    fi

    if [[ ${available_mb:-0} -lt $required_mb ]]; then
        log_error "Insufficient disk space: ${available_mb}M available, ${required_mb}M required"
        log_info "Free space on / — e.g. remove unused /opt apps. See: df -h /"
        return 1
    fi

    log_success "✓ Disk space OK (${available_mb}M available)"
    return 0
}

# Validate package files
check_package_files() {
    log_info "Validating package files..."

    local errors=0

    if [[ ! -f "$PACKAGES_FILE" ]]; then
        log_error "Missing: packages/arch.package"
        errors=$((errors + 1))
    elif [[ ! -r "$PACKAGES_FILE" ]]; then
        log_error "Cannot read: packages/arch.package"
        errors=$((errors + 1))
    fi

    if [[ ! -f "$AUR_PACKAGES_FILE" ]]; then
        log_error "Missing: packages/aur.package"
        errors=$((errors + 1))
    elif [[ ! -r "$AUR_PACKAGES_FILE" ]]; then
        log_error "Cannot read: packages/aur.package"
        errors=$((errors + 1))
    fi

    # Check for syntax errors (invalid package names)
    local invalid_packages=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
        if [[ ! "$pkg" =~ ^[a-z0-9@._+-]+$ ]]; then
            invalid_packages+=("$pkg")
        fi
    done < "$PACKAGES_FILE"

    if [[ ${#invalid_packages[@]} -gt 0 ]]; then
        log_error "Invalid package names in arch.package:"
        printf '  ✗ %s\n' "${invalid_packages[@]}"
        errors=$((errors + 1))
    fi

    if [[ $errors -gt 0 ]]; then
        return 1
    fi

    log_success "✓ Package files valid"
    return 0
}

# Check yay is installed
check_yay() {
    log_info "Checking yay AUR helper..."

    if ! command -v yay &>/dev/null; then
        log_warning "yay not installed"
        log_info "Will install yay during package installation"
        return 0
    fi

    log_success "✓ yay installed"
    return 0
}

# Check pacman database
check_pacman_db() {
    log_info "Checking pacman database..."

    # Check if database is locked
    if [[ -f /var/lib/pacman/db.lck ]]; then
        log_error "Pacman database is locked"
        log_info "Another package manager may be running"
        log_info "If not, remove: sudo rm /var/lib/pacman/db.lck"
        return 1
    fi

    # Check if database is outdated (more than 7 days)
    local db_age_days=0
    if [[ -f /var/lib/pacman/sync/core.db ]]; then
        local db_mtime=$(stat -c %Y /var/lib/pacman/sync/core.db)
        local now=$(date +%s)
        db_age_days=$(( (now - db_mtime) / 86400 ))
    fi

    if [[ $db_age_days -gt 7 ]]; then
        log_warning "Pacman database is ${db_age_days} days old"
        log_info "Will sync database during installation"
    fi

    log_success "✓ Pacman database OK"
    return 0
}

# Check for conflicting processes
check_conflicts() {
    log_info "Checking for conflicting processes..."

    local conflicts=()

    if pgrep -x pacman &>/dev/null; then
        conflicts+=("pacman")
    fi

    if pgrep -x yay &>/dev/null; then
        conflicts+=("yay")
    fi

    if pgrep -x pamac &>/dev/null; then
        conflicts+=("pamac")
    fi

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        log_error "Package managers already running: ${conflicts[*]}"
        log_info "Wait for them to finish or kill the processes"
        return 1
    fi

    log_success "✓ No conflicts detected"
    return 0
}

# Run all pre-flight checks
run_preflight_checks() {
    log_section "Pre-flight Checks"

    local failed=0

    check_network || failed=$((failed + 1))
    echo

    check_disk_space || failed=$((failed + 1))
    echo

    check_package_files || failed=$((failed + 1))
    echo

    check_yay || failed=$((failed + 1))
    echo

    check_pacman_db || failed=$((failed + 1))
    echo

    check_conflicts || failed=$((failed + 1))
    echo

    if [[ $failed -gt 0 ]]; then
        log_error "Pre-flight checks failed ($failed issues)"
        log_info "Fix the issues above before running installation"
        return 1
    fi

    log_success "✓ All pre-flight checks passed"
    return 0
}
