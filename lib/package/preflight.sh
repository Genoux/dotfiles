#!/bin/bash
# Pre-flight checks for installation

# Shared by check_pacman_lock and check_conflicts — the one list of "what
# else might be holding the pacman db lock or racing this install."
PACKAGE_MANAGER_PROCESSES=("pacman" "yay" "paru" "pamac")

# Enable the multilib repository (needed for lib32-* GPU/Wine packages).
# Must run before sync_pacman_db/check_package_names — those lib32-* names
# can only resolve once multilib is both enabled AND synced. Verified against
# pacman's own parsed config (pacman-conf), not a raw text match, so an
# already-correct pacman.conf is left untouched and a failed edit is never
# reported as success.
ensure_multilib_enabled() {
    local pacman_conf="${PACMAN_CONF:-/etc/pacman.conf}"

    log_info "Checking multilib repository..."

    if pacman-conf --config "$pacman_conf" --repo=multilib &>/dev/null; then
        log_success "✓ multilib already enabled"
        return 0
    fi

    if [[ ! -f "$pacman_conf" ]]; then
        log_error "$pacman_conf not found"
        return 1
    fi

    sudo sed -i 's/^#\[multilib\]/[multilib]/' "$pacman_conf"
    sudo sed -i '/^\[multilib\]$/,/^\[/ s/^#Include = \/etc\/pacman\.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/' "$pacman_conf"

    if pacman-conf --config "$pacman_conf" --repo=multilib &>/dev/null; then
        log_success "✓ multilib enabled"
        return 0
    fi

    log_error "Failed to enable multilib repository in $pacman_conf"
    return 1
}

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

    # 2GB floor. A from-scratch install wants more headroom, but on an already
    # populated machine (re-sync) the real need is small, and a tight root can't
    # spare 5GB. Override with DOTFILES_MIN_DISK_MB for a true fresh install.
    local required_mb="${DOTFILES_MIN_DISK_MB:-2000}"
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

# Validate every official + AUR package name actually resolves before
# installing anything. A typo or renamed/orphaned AUR package must abort the
# whole run with the exact bad names, not silently "not found, skipping" one
# package deep into the transaction.
check_package_names() {
    log_info "Validating package names against pacman and the AUR..."

    local official_packages=() aur_packages=()
    read_official_install_packages official_packages
    read_aur_install_packages aur_packages

    local bad_official=()
    if [[ ${#official_packages[@]} -gt 0 ]]; then
        local -A official_seen=()
        while IFS= read -r name; do
            [[ -n "$name" ]] && official_seen["$name"]=1
        done < <(pacman -Si -- "${official_packages[@]}" 2>/dev/null | awk -F': ' '/^Name/ {print $2}')

        for pkg in "${official_packages[@]}"; do
            [[ -v official_seen["$pkg"] ]] && continue
            # Not a regular package — a package group ("base-devel" style) is
            # also a valid pacman -S target.
            if [[ -n "$(pacman -Sg -- "$pkg" 2>/dev/null)" ]]; then
                continue
            fi
            bad_official+=("$pkg")
        done
    fi

    local bad_aur=()
    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        if ! command -v curl &>/dev/null; then
            log_warning "curl not installed — skipping AUR name validation"
        else
            local -a curl_args=(-sG --data-urlencode "v=5" --data-urlencode "type=info")
            local pkg
            for pkg in "${aur_packages[@]}"; do
                curl_args+=(--data-urlencode "arg[]=$pkg")
            done

            local response
            response=$(curl "${curl_args[@]}" "https://aur.archlinux.org/rpc/") || response=""

            if [[ -z "$response" ]] || ! command -v jq &>/dev/null; then
                log_warning "Could not reach the AUR RPC — skipping AUR name validation"
            else
                local -A aur_seen=()
                while IFS= read -r name; do
                    [[ -n "$name" ]] && aur_seen["$name"]=1
                done < <(printf '%s' "$response" | jq -r '.results[].Name' 2>/dev/null)

                for pkg in "${aur_packages[@]}"; do
                    [[ -v aur_seen["$pkg"] ]] || bad_aur+=("$pkg")
                done
            fi
        fi
    fi

    if [[ ${#bad_official[@]} -gt 0 || ${#bad_aur[@]} -gt 0 ]]; then
        log_error "Unknown package names — fix packages/*.package before installing:"
        printf '  ✗ %s (official)\n' "${bad_official[@]}"
        printf '  ✗ %s (AUR)\n' "${bad_aur[@]}"
        return 1
    fi

    log_success "✓ All package names resolve"
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

# Check/clear a stale pacman lock. Must run before sync_pacman_db — a lock
# blocks `pacman -Sy` outright.
check_pacman_lock() {
    log_info "Checking pacman database lock..."

    if [[ -f /var/lib/pacman/db.lck ]]; then
        local pattern
        pattern=$(IFS='|'; echo "${PACKAGE_MANAGER_PROCESSES[*]}")
        if pgrep -x "$pattern" &>/dev/null; then
            log_error "Pacman database is locked (package manager running)"
            log_info "Wait for it to finish, then retry"
            return 1
        fi
        log_warning "Stale pacman lock detected (no package manager running), removing"
        sudo rm /var/lib/pacman/db.lck || {
            log_error "Failed to remove stale lock: sudo rm /var/lib/pacman/db.lck"
            return 1
        }
    fi

    log_success "✓ No pacman lock"
    return 0
}

# Sync the pacman sync DB. check_package_names needs this to have already
# happened — pacman -Si against a stale/never-synced DB reports every name as
# unknown, which used to make a fresh install's preflight reject its own
# curated package lists. This is now the only `pacman -Sy` in the install
# path: packages_prepare (core.sh) used to run a second one later, which
# just widened the window between syncing and the eventual `-Syu` for no
# benefit — a partial-upgrade risk if anything installs packages in between
# (hardware_detect doesn't — it only detects and selects manifests, never
# installs during `./dotfiles install`).
sync_pacman_db() {
    log_info "Syncing pacman database..."

    if ! run_command_logged "Sync pacman database" sudo pacman -Sy --noconfirm; then
        log_error "Failed to sync pacman database"
        return 1
    fi

    log_success "✓ Pacman database synced"
    return 0
}

# Check for conflicting processes
check_conflicts() {
    log_info "Checking for conflicting processes..."

    local conflicts=()

    for proc in "${PACKAGE_MANAGER_PROCESSES[@]}"; do
        if pgrep -x "$proc" &>/dev/null; then
            conflicts+=("$proc")
        fi
    done

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

    ensure_multilib_enabled || failed=$((failed + 1))
    echo

    if ! check_pacman_lock; then
        failed=$((failed + 1))
    elif ! sync_pacman_db; then
        failed=$((failed + 1))
    fi
    echo

    check_package_names || failed=$((failed + 1))
    echo

    check_yay || failed=$((failed + 1))
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
