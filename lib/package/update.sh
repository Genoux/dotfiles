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

_update_failed_due_to_disk_space() {
    grep -qE "Partition / too full|not enough free disk space|Not enough free space on /" "$DOTFILES_LOG_FILE" 2>/dev/null
}

_update_failed_due_to_corrupt_sources() {
    grep -qE "did not pass the validity check|Validation of source files failed" "$DOTFILES_LOG_FILE" 2>/dev/null
}

# Only the build command sees the npm override: a user's ~/.npmrc prefix breaks
# some AUR builds, but the file itself is never touched.
_run_yay_update() {
    local step_name="$1"
    local answer_clean="$2"

    run_command_logged "$step_name" \
        env -u NPM_CONFIG_PREFIX -u npm_config_prefix -u NPM_CONFIG_GLOBALCONFIG -u npm_config_globalconfig \
            NPM_CONFIG_USERCONFIG=/dev/null npm_config_userconfig=/dev/null \
            yay -Sua --noconfirm --answerclean "$answer_clean" --answerdiff N
}

# 130/143 = SIGINT/SIGTERM: the user asked to stop, so nothing may start after.
_was_cancelled() {
    (( $1 == 130 || $1 == 143 ))
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
    recent_errors=$(grep -iE "error:|failed:" "$DOTFILES_LOG_FILE" 2>/dev/null | tail -n 8 || true)

    log_error "$fallback_message"
    if [[ -n "$recent_errors" ]]; then
        echo
        echo "$recent_errors"
    fi
}

# Names the AUR packages the last yay run failed on, from yay's own messages.
_failed_aur_packages() {
    { tac "$DOTFILES_LOG_FILE" | sed '/Starting: Update AUR packages/q' | tac; } 2>/dev/null \
        | sed -nE \
            -e 's/.*error making: ([^ ]+[^ -])( - |-)exit status.*/\1/p' \
            -e 's|.*error downloading sources: .*/([^/ ]+)[[:space:]]*$|\1|p' \
        | awk '!seen[$0]++' || true
}

# pacman owns the DB sync and the official packages. Dependency conflicts are
# never auto-resolved: "Remove X? [y/N]" is answered No by --noconfirm, the
# transaction aborts and the failure stays visible, so it fails the update.
# A broken AUR package must not: it is recorded in the caller's aur_warning and
# retried on the next run. The one yay retry covers corrupt cached sources.
# Reads the caller's cancelled_status: yay may swallow SIGINT and exit 1.
_update_packages() {
    run_command_logged "Update official packages" sudo pacman -Syu --noconfirm || return $?

    local aur_status=0
    _update_aur_packages || aur_status=$?
    if (( aur_status == 0 )); then
        return 0
    fi
    if (( cancelled_status != 0 )) || _was_cancelled "$aur_status"; then
        return "$aur_status"
    fi

    local failed_packages
    failed_packages=$(_failed_aur_packages | paste -sd ' ')
    aur_warning="AUR packages not updated: ${failed_packages:-see the log} - they will be retried on the next update"
}

_update_aur_packages() {
    local update_status=0
    _run_yay_update "Update AUR packages" N || update_status=$?

    if (( update_status == 0 || cancelled_status != 0 )) || _was_cancelled "$update_status" \
        || ! _update_failed_due_to_corrupt_sources; then
        return "$update_status"
    fi

    log_warning "Source archives failed validation, purging source cache and retrying once..."
    _purge_cached_sources
    _run_yay_update "Update AUR packages (clean retry)" A
}

# Update system packages (official + AUR + Flatpak)
packages_update() {
    if ! ensure_sudo; then
        log_error "Failed to obtain sudo privileges"
        return 1
    fi

    init_logging "package"
    start_log_monitor

    # Without a handler, bash exits as soon as the foreground child dies from
    # SIGINT/SIGTERM and skips the cleanup below, leaving the terminal in the
    # alternate screen with a hidden cursor. The handler only records the
    # signal: the flow still reaches cleanup and returns the cancel status.
    local cancelled_status=0
    local aur_warning=""
    local previous_traps
    previous_traps=$(trap -p INT TERM)
    trap 'cancelled_status=130' INT
    trap 'cancelled_status=143' TERM

    # yay may be broken after a libalpm/pacman upgrade — fix it before using it
    local update_failed=false
    local failure_message="System update failed"

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

    if ! $update_failed && (( cancelled_status == 0 )); then
        local update_status=0
        _update_packages || update_status=$?
        (( cancelled_status != 0 )) || ! _was_cancelled "$update_status" || cancelled_status=$update_status
        (( update_status == 0 )) || update_failed=true
    fi

    if ! $update_failed && (( cancelled_status == 0 )) && command -v flatpak &>/dev/null; then
        local flatpak_status=0
        run_command_logged "Update Flatpak apps" flatpak update -y --noninteractive || flatpak_status=$?
        (( cancelled_status != 0 )) || ! _was_cancelled "$flatpak_status" || cancelled_status=$flatpak_status
        if (( flatpak_status != 0 )); then
            update_failed=true
            failure_message="System update failed: Flatpak update failed"
        fi
    fi

    if (( cancelled_status != 0 )); then
        update_failed=true
        failure_message="System update cancelled"
    fi

    trap - INT TERM
    eval "$previous_traps"

    finish_logging
    sleep 1

    if $update_failed; then
        stop_log_monitor
        _report_update_failure "$failure_message"
        return "$(( cancelled_status != 0 ? cancelled_status : 1 ))"
    fi

    stop_log_monitor true
    log_success "System update complete"
    [[ -z "$aur_warning" ]] || log_warning "$aur_warning"
}
