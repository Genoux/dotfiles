#!/bin/bash
# System package updates

UPDATE_MIN_ROOT_FREE_KIB="${DOTFILES_UPDATE_MIN_ROOT_FREE_KIB:-3145728}" # 3 GiB
UPDATE_JOURNAL_TARGET="${DOTFILES_UPDATE_JOURNAL_TARGET:-512M}"

# Rebuild yay if it's broken (e.g., after libalpm update)
rebuild_yay_if_broken() {
    if ! command -v yay &>/dev/null || yay --version &>/dev/null; then
        return 0
    fi

    log_warning "yay is broken (likely due to library update), rebuilding..."

    if ! run_command_logged "Rebuild yay" bash -c '
        cd /tmp
        rm -rf yay
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
    '; then
        log_error "Failed to rebuild yay"
        return 1
    fi

    log_success "yay rebuilt successfully"
}

# Parse the log file for packages that pacman wants to remove due to conflicts
# Matches lines like: "Remove geocode-glib-common? [y/N]"
_detect_conflict_packages() {
    grep -oP "Remove \K[a-zA-Z0-9@._+:-]+" "$DOTFILES_LOG_FILE" 2>/dev/null | sort -u
}

# Remove old cached packages, keeping one version per package for rollback
_clean_package_cache() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Clean package caches" >> "$DOTFILES_LOG_FILE"

    local -a download_dirs=()
    shopt -s nullglob
    download_dirs=(/var/cache/pacman/pkg/download-*)
    shopt -u nullglob

    if [[ ${#download_dirs[@]} -gt 0 ]]; then
        sudo rm -rf "${download_dirs[@]}" 2>/dev/null || true
        echo "Removed ${#download_dirs[@]} leftover pacman download dirs" >> "$DOTFILES_LOG_FILE"
    fi

    if command -v paccache &>/dev/null; then
        sudo paccache -rk1 -q 2>/dev/null || true
        sudo paccache -ruk0 -q 2>/dev/null || true
    else
        sudo pacman -Sc --noconfirm 2>/dev/null || true
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Clean package caches" >> "$DOTFILES_LOG_FILE"
}

_root_available_kib() {
    df -Pk / | awk 'NR == 2 { print $4 }'
}

_format_kib() {
    local kib="$1"
    awk -v kib="$kib" 'BEGIN {
        if (kib >= 1048576) {
            printf "%.1f GiB", kib / 1048576
        } else if (kib >= 1024) {
            printf "%.1f MiB", kib / 1024
        } else {
            printf "%d KiB", kib
        }
    }'
}

_log_root_space() {
    local label="$1"
    local free_kib
    free_kib=$(_root_available_kib)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $label: / has $(_format_kib "$free_kib") free" >> "$DOTFILES_LOG_FILE"
}

_vacuum_journal_for_update() {
    if ! command -v journalctl &>/dev/null; then
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Vacuum journal for update" >> "$DOTFILES_LOG_FILE"
    sudo journalctl --vacuum-size="$UPDATE_JOURNAL_TARGET" >> "$DOTFILES_LOG_FILE" 2>&1 || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Vacuum journal for update" >> "$DOTFILES_LOG_FILE"
}

_ensure_update_disk_space() {
    local free_kib
    free_kib=$(_root_available_kib)

    if (( free_kib >= UPDATE_MIN_ROOT_FREE_KIB )); then
        _log_root_space "Disk preflight"
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Low root space before update: $(_format_kib "$free_kib") free, $(_format_kib "$UPDATE_MIN_ROOT_FREE_KIB") required" >> "$DOTFILES_LOG_FILE"

    _clean_package_cache
    _vacuum_journal_for_update

    free_kib=$(_root_available_kib)
    if (( free_kib >= UPDATE_MIN_ROOT_FREE_KIB )); then
        _log_root_space "Disk preflight after cleanup"
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Not enough free space on / after cleanup" >> "$DOTFILES_LOG_FILE"
    echo "Root filesystem needs at least $(_format_kib "$UPDATE_MIN_ROOT_FREE_KIB") free before a full update." >> "$DOTFILES_LOG_FILE"
    echo "Current free space: $(_format_kib "$free_kib")" >> "$DOTFILES_LOG_FILE"
    return 1
}

_restore_npmrc() {
    local npmrc_backup="$1"

    if [[ -n "$npmrc_backup" && -f "$npmrc_backup" ]]; then
        mv "$npmrc_backup" "$HOME/.npmrc" 2>/dev/null || true
    fi
}

_update_failed_due_to_disk_space() {
    grep -qE "Partition / too full|not enough free disk space|Not enough free space on /" "$DOTFILES_LOG_FILE" 2>/dev/null
}

_purge_cached_sources() {
    if [[ ! -d "$HOME/.cache/yay" ]]; then
        return 0
    fi

    while IFS= read -r -d '' source_archive; do
        rm -f "$source_archive" 2>/dev/null || true
    done < <(
        find "$HOME/.cache/yay" -maxdepth 2 \
            \( -name "*.tar.gz" -o -name "*.tar.xz" -o -name "*.tar.zst" -o -name "*.zip" \) \
            -print0 2>/dev/null
    )
}

_report_update_failure() {
    local fallback_message="${1:-System update failed}"

    if _update_failed_due_to_disk_space; then
        local free_kib
        free_kib=$(_root_available_kib)
        log_error "System update failed: not enough free space on /"
        log_info "Root free space: $(_format_kib "$free_kib")"
        log_info "Free more root space or increase / before running the update again."
        return
    fi

    local recent_errors
    recent_errors=$(grep -E "error:|Failed:" "$DOTFILES_LOG_FILE" 2>/dev/null | tail -n 8 || true)

    log_error "$fallback_message"
    if [[ -n "$recent_errors" ]]; then
        echo
        echo "$recent_errors"
    fi
}

# Update system packages (official + AUR)
packages_update() {
    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges"
        return 1
    fi

    init_logging "package"
    start_log_monitor

    # yay may be broken after a libalpm/pacman upgrade — fix it before using it
    local update_failed=false
    local failure_message="System update failed"
    local npmrc_backup=""

    if ! rebuild_yay_if_broken; then
        update_failed=true
        failure_message="System update failed: could not rebuild yay"
    elif ! ensure_yay_installed; then
        update_failed=true
        failure_message="System update failed: yay is not available"
    elif ! _ensure_update_disk_space; then
        update_failed=true
        failure_message="System update skipped: not enough free space on /"
    fi

    # Neutralize npm config that breaks some AUR builds
    if ! $update_failed && [[ -f "$HOME/.npmrc" ]]; then
        npmrc_backup="$HOME/.npmrc.dotfiles-backup-$(date +%s)"
        mv "$HOME/.npmrc" "$npmrc_backup" 2>/dev/null || true
    fi
    export NPM_CONFIG_USERCONFIG=/dev/null
    unset NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG npm_config_globalconfig

    # yay -Syu syncs the DB and updates both official and AUR packages in one pass
    if ! $update_failed && ! run_command_logged "Update system and AUR packages" yay -Syu --noconfirm --answerclean N --answerdiff N; then
        # Check if the failure is due to package conflicts (pacman prompts "Remove X? [y/N]"
        # which --noconfirm answers No, causing the transaction to abort)
        local -a conflicts=()
        mapfile -t conflicts < <(_detect_conflict_packages)

        if _update_failed_due_to_disk_space; then
            update_failed=true
        elif [[ ${#conflicts[@]} -gt 0 ]]; then
            log_warning "Removing conflicting packages: ${conflicts[*]}"
            sudo pacman -Rdd --noconfirm "${conflicts[@]}" 2>&1 | tee -a "$DOTFILES_LOG_FILE" || true

            if ! run_command_logged "Update system and AUR packages (after conflict resolution)" yay -Syu --noconfirm --answerclean N --answerdiff N; then
                update_failed=true
            fi
        else
            # Non-conflict failure — purge cached source tarballs (corrupted checksums) and retry
            log_warning "Update failed, purging source cache and retrying..."
            _purge_cached_sources

            if ! run_command_logged "Update system and AUR packages (clean retry)" yay -Syu --noconfirm --answerclean A --answerdiff N; then
                update_failed=true
            fi
        fi
    fi

    _restore_npmrc "$npmrc_backup"

    finish_logging
    sleep 1

    if $update_failed; then
        stop_log_monitor
        _report_update_failure "$failure_message"
        return 1
    fi

    stop_log_monitor true
    log_success "System update complete"
}
