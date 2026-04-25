#!/bin/bash
# System cleanup operations

DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"

if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Remove leftover pacman temp download directories (created by interrupted updates)
cleanup_temp_downloads() {
    local count
    count=$(find /var/cache/pacman/pkg -maxdepth 1 -name 'download-*' -type d 2>/dev/null | wc -l)

    if [[ "$count" -eq 0 ]]; then
        log_success "No leftover temp downloads"
        return 0
    fi

    log_info "Removing $count leftover pacman download dirs..."
    sudo find /var/cache/pacman/pkg -maxdepth 1 -name 'download-*' -type d -exec rm -rf {} + 2>/dev/null || true
    log_success "Removed $count temp download dirs"
}

# Clean pacman package cache (keep last N versions per package)
cleanup_pacman_cache() {
    local keep="${1:-2}"

    if ! command -v paccache &>/dev/null; then
        # paccache is in pacman-contrib; fall back to basic clean
        log_warning "paccache not found, using pacman -Sc fallback"
        sudo pacman -Sc --noconfirm 2>/dev/null || true
        return
    fi

    local before
    before=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1 || echo "?")

    sudo paccache -rk"$keep" --noconfirm 2>/dev/null || true
    sudo paccache -ruk0 --noconfirm 2>/dev/null || true  # remove cache for uninstalled packages

    local after
    after=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1 || echo "?")
    log_success "Pacman cache: $before → $after"
}

# Clean AUR/yay build cache
cleanup_aur_cache() {
    local before
    before=$(du -sh "$HOME/.cache/yay/" 2>/dev/null | cut -f1 || echo "0")

    yay -Sc --noconfirm 2>/dev/null || true

    local after
    after=$(du -sh "$HOME/.cache/yay/" 2>/dev/null | cut -f1 || echo "0")
    log_success "AUR cache: $before → $after"
}

# Remove orphaned packages (interactive confirmation)
cleanup_orphans() {
    local orphans
    orphans=$(pacman -Qtdq 2>/dev/null || true)

    if [[ -z "$orphans" ]]; then
        log_success "No orphaned packages"
        return 0
    fi

    local count
    count=$(echo "$orphans" | wc -l)

    log_section "Orphaned Packages ($count)"
    echo "$orphans" | while read -r pkg; do echo "  - $pkg"; done
    echo

    if gum confirm "Remove $count orphaned packages?"; then
        echo "$orphans" | xargs sudo pacman -Rns --noconfirm
        log_success "Removed $count orphaned packages"
    else
        log_info "Skipped"
    fi
}

# Empty trash
cleanup_trash() {
    local size
    size=$(du -sh "$HOME/.local/share/Trash/" 2>/dev/null | cut -f1 || echo "0")

    if [[ "$size" == "0" ]] || [[ ! -d "$HOME/.local/share/Trash/files" ]]; then
        log_success "Trash is empty"
        return 0
    fi

    log_info "Trash size: $size"
    rm -rf "$HOME/.local/share/Trash/files/"* "$HOME/.local/share/Trash/info/"* 2>/dev/null || true
    log_success "Trash emptied ($size freed)"
}

# Clear npm cache
cleanup_npm_cache() {
    if ! command -v npm &>/dev/null; then
        log_info "npm not installed, skipping"
        return 0
    fi

    local before
    before=$(du -sh "$HOME/.npm/_cacache/" 2>/dev/null | cut -f1 || echo "0")
    npm cache clean --force 2>/dev/null || true
    log_success "npm cache cleared ($before freed)"
}

# Clear large known application caches under ~/.cache
cleanup_app_caches() {
    local total_freed=0

    # Map of cache dirs to human-readable names
    local -A app_caches=(
        ["$HOME/.cache/spotify/Data"]="Spotify"
        ["$HOME/.cache/google-chrome"]="Chrome"
        ["$HOME/.cache/chromium"]="Chromium"
        ["$HOME/.cache/mozilla"]="Firefox"
        ["$HOME/.cache/pip"]="pip"
        ["$HOME/.cache/go"]="Go"
        ["$HOME/.cache/thumbnails"]="Thumbnails"
    )

    for cache_dir in "${!app_caches[@]}"; do
        [[ ! -d "$cache_dir" ]] && continue
        local size
        size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1 || echo "0")
        rm -rf "$cache_dir" 2>/dev/null || true
        log_success "${app_caches[$cache_dir]} cache cleared ($size)"
    done
}

# Vacuum systemd journal logs
cleanup_journal() {
    local before
    before=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+ \w+' | head -1 || echo "?")

    log_info "Vacuuming journal (keeping 2 weeks)..."
    sudo journalctl --vacuum-time=2weeks 2>&1 | grep -v "^$" || true

    local after
    after=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+ \w+' | head -1 || echo "?")
    log_success "Journal: $before → $after"
}

# Run all cleanup tasks (non-interactive for orphans)
cleanup_all() {
    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges"
        return 1
    fi

    init_logging "daily"
    start_log_monitor

    run_command_logged "Empty trash" bash -c '
        size=$(du -sh "$HOME/.local/share/Trash/" 2>/dev/null | cut -f1 || echo "0")
        rm -rf "$HOME/.local/share/Trash/files/"* "$HOME/.local/share/Trash/info/"* 2>/dev/null || true
        echo "Freed $size"
    '

    run_command_logged "Clear npm cache" bash -c '
        if command -v npm &>/dev/null; then
            size=$(du -sh "$HOME/.npm/_cacache/" 2>/dev/null | cut -f1 || echo "0")
            npm cache clean --force 2>/dev/null || true
            echo "Freed $size"
        else
            echo "npm not installed, skipped"
        fi
    '

    run_command_logged "Clear app caches" bash -c '
        for dir in \
            "$HOME/.cache/spotify/Data" \
            "$HOME/.cache/google-chrome" \
            "$HOME/.cache/chromium" \
            "$HOME/.cache/mozilla" \
            "$HOME/.cache/pip" \
            "$HOME/.cache/go" \
            "$HOME/.cache/thumbnails"; do
            [[ -d "$dir" ]] || continue
            size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "0")
            rm -rf "$dir" 2>/dev/null || true
            echo "Cleared $(basename $dir): $size"
        done
    '

    run_command_logged "Remove temp downloads" bash -c '
        count=$(find /var/cache/pacman/pkg -maxdepth 1 -name "download-*" -type d 2>/dev/null | wc -l)
        if [[ "$count" -gt 0 ]]; then
            sudo find /var/cache/pacman/pkg -maxdepth 1 -name "download-*" -type d -exec rm -rf {} + 2>/dev/null || true
            echo "Removed $count temp dirs"
        else
            echo "None found"
        fi
    '

    run_command_logged "Clean pacman cache" bash -c '
        if command -v paccache &>/dev/null; then
            sudo paccache -rk2 --noconfirm 2>/dev/null || true
            sudo paccache -ruk0 --noconfirm 2>/dev/null || true
        else
            sudo pacman -Sc --noconfirm 2>/dev/null || true
        fi
    '

    run_command_logged "Clean AUR cache" bash -c 'yay -Sc --noconfirm 2>&1 || true'

    run_command_logged "Vacuum journal logs" sudo journalctl --vacuum-time=2weeks

    finish_logging
    sleep 1
    stop_log_monitor true

    # Orphans need interactive confirmation — handle after log monitor
    echo
    local orphans
    orphans=$(pacman -Qtdq 2>/dev/null || true)
    if [[ -n "$orphans" ]]; then
        local count
        count=$(echo "$orphans" | wc -l)
        log_section "Orphaned Packages ($count)"
        echo "$orphans" | while read -r pkg; do echo "  - $pkg"; done
        echo
        if gum confirm "Remove $count orphaned packages?"; then
            echo "$orphans" | xargs sudo pacman -Rns --noconfirm
            log_success "Removed $count orphaned packages"
        fi
    else
        log_success "No orphaned packages"
    fi

    echo
    log_success "Cleanup complete"
    echo
    df -h / | tail -1 | awk '{printf "  Disk: %s used / %s total (%s free)\n", $3, $2, $4}'
}

# Quick summary for menu header
cleanup_show_summary() {
    local free
    free=$(df -h / | tail -1 | awk '{print $4}')
    local used_pct
    used_pct=$(df / | tail -1 | awk '{print $5}')
    local trash_size
    trash_size=$(du -sh "$HOME/.local/share/Trash/" 2>/dev/null | cut -f1 || echo "0")
    local orphan_count
    orphan_count=$(pacman -Qtdq 2>/dev/null | wc -l || echo 0)
    show_quick_summary "Disk free" "$free ($used_pct used)" "Trash" "$trash_size" "Orphans" "$orphan_count packages"
}

# Detailed cleanup status
cleanup_status() {
    log_section "System Cleanup Status"
    echo

    df -h / | tail -1 | awk '{printf "  Root:    %s used / %s total (%s free)\n", $3, $2, $4}'
    echo

    # User space
    local trash_size
    trash_size=$(du -sh "$HOME/.local/share/Trash/" 2>/dev/null | cut -f1 || echo "0")
    [[ "$trash_size" != "0" ]] && log_warning "Trash: $trash_size" || log_success "Trash: empty"

    local npm_size
    npm_size=$(du -sh "$HOME/.npm/_cacache/" 2>/dev/null | cut -f1 || echo "0")
    show_info "npm cache" "$npm_size"

    local spotify_size
    spotify_size=$(du -sh "$HOME/.cache/spotify/Data" 2>/dev/null | cut -f1 || echo "0")
    show_info "Spotify cache" "$spotify_size"

    local cache_size
    cache_size=$(du -sh "$HOME/.cache/" 2>/dev/null | cut -f1 || echo "?")
    show_info "~/.cache total" "$cache_size"

    echo

    # System space
    local pkg_cache_size
    pkg_cache_size=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1 || echo "?")
    show_info "Pacman cache" "$pkg_cache_size"

    local aur_size
    aur_size=$(du -sh "$HOME/.cache/yay/" 2>/dev/null | cut -f1 || echo "0")
    show_info "AUR cache" "$aur_size"

    local temp_count
    temp_count=$(find /var/cache/pacman/pkg -maxdepth 1 -name 'download-*' -type d 2>/dev/null | wc -l)
    if [[ "$temp_count" -gt 0 ]]; then
        log_warning "Temp downloads: $temp_count leftover dirs"
    else
        log_success "Temp downloads: clean"
    fi

    local orphan_count
    orphan_count=$(pacman -Qtdq 2>/dev/null | wc -l || echo 0)
    if [[ "$orphan_count" -gt 0 ]]; then
        log_warning "Orphaned packages: $orphan_count"
    else
        log_success "Orphaned packages: none"
    fi

    local journal_size
    journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+ \w+' | head -1 || echo "?")
    show_info "Journal logs" "$journal_size"

    echo
}

# Interactive cleanup menu
cleanup_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"

    while true; do
        clear_screen "System Cleanup"
        cleanup_show_summary

        local action
        action=$(choose_option \
            "Clean All" \
            "Empty Trash" \
            "Clear App Caches" \
            "Clear npm Cache" \
            "Remove Orphans" \
            "Clean Package Cache" \
            "Clean AUR Cache" \
            "Vacuum Journal" \
            "Show Details" \
            "Back")

        [[ -z "$action" ]] && return

        case "$action" in
            "Clean All")
                cleanup_all
                pause
                ;;
            "Empty Trash")
                run_operation "" cleanup_trash
                ;;
            "Clear App Caches")
                run_operation "" cleanup_app_caches
                ;;
            "Clear npm Cache")
                run_operation "" cleanup_npm_cache
                ;;
            "Remove Orphans")
                run_operation "" cleanup_orphans
                ;;
            "Clean Package Cache")
                run_operation "" cleanup_pacman_cache
                ;;
            "Clean AUR Cache")
                run_operation "" cleanup_aur_cache
                ;;
            "Vacuum Journal")
                run_operation "" cleanup_journal
                ;;
            "Show Details")
                run_operation "" cleanup_status
                ;;
            "Back")
                return
                ;;
        esac
    done
}
