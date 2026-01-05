#!/bin/bash
# Dotfiles updates management module

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# State file
STATE_DIR="$HOME/.local/state/dotfiles"
STATE_FILE="$STATE_DIR/updates.state"

# Check script location
CHECK_SCRIPT="$HOME/.local/bin/system-check-dotfiles-updates"
UPDATE_SCRIPT="$HOME/.local/bin/system-update-dotfiles"

# Read current update state
read_update_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi
    
    source "$STATE_FILE" 2>/dev/null || return 1
    return 0
}

# Show update status
updates_status() {
    local skip_title="${1:-}"
    
    if [[ "$skip_title" != "--skip-title" ]]; then
        clear_screen "Dotfiles Updates"
    fi
    
    # Show version
    local version="unknown"
    if [[ -f "$DOTFILES_DIR/VERSION" ]]; then
        version=$(cat "$DOTFILES_DIR/VERSION" 2>/dev/null || echo "unknown")
    fi
    show_info "Version" "v$version"
    
    # Show commit hash
    local commit_short="unknown"
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        commit_short=$(cd "$DOTFILES_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi
    show_info "Commit" "$commit_short"
    echo
    
    # Read state
    if ! read_update_state; then
        show_info "Status" "Not checked yet"
        show_info "Action" "Run 'Check Now' to check for updates"
        echo
        return
    fi
    
    # Show status based on state
    if [[ "${UPDATES_AVAILABLE:-false}" == "true" ]]; then
        show_info "Updates" "${COMMIT_COUNT:-0} commit(s) available"
        show_info "Status" "Updates ready to install"
        
        # Show commit preview if in git repo
        if [[ -d "$DOTFILES_DIR/.git" ]]; then
            echo
            log_info "Latest commits:"
            echo
            (cd "$DOTFILES_DIR" && git log HEAD..origin/main --oneline --color=always -5 2>/dev/null) || true
        fi
    elif [[ "${UPDATES_AVAILABLE:-false}" == "error" ]]; then
        show_info "Status" "Error checking for updates"
        show_info "Error" "${ERROR_MESSAGE:-Unknown error}"
    else
        show_info "Status" "Up to date"
        show_info "Checked" "$(date -d "@${LAST_CHECK:-0}" '+%Y-%m-%d %H:%M' 2>/dev/null || echo 'Never')"
    fi
    
    echo
}

# Check for updates (manual check with output)
updates_check() {
    clear_screen "Checking for Updates"
    
    if [[ ! -x "$CHECK_SCRIPT" ]]; then
        log_error "Check script not found: $CHECK_SCRIPT"
        pause
        return 1
    fi
    
    log_info "Fetching remote changes..."
    echo
    
    # Run check script without --silent to see output
    if "$CHECK_SCRIPT"; then
        echo
        log_success "No updates available"
        echo
        show_info "Status" "Your dotfiles are up to date"
    elif [[ $? -eq 1 ]]; then
        echo
        log_success "Updates found!"
        echo
        
        # Re-read state and show details
        if read_update_state; then
            show_info "Updates" "${COMMIT_COUNT:-0} new commit(s)"
            
            # Show commit preview
            if [[ -d "$DOTFILES_DIR/.git" ]]; then
                echo
                log_info "Latest commits:"
                echo
                (cd "$DOTFILES_DIR" && git log HEAD..origin/main --oneline --color=always -5 2>/dev/null) || true
            fi
        fi
    else
        echo
        log_error "Failed to check for updates"
    fi
    
    echo
}

# Apply updates (pull changes)
updates_apply() {
    if [[ ! -x "$UPDATE_SCRIPT" ]]; then
        log_error "Update script not found: $UPDATE_SCRIPT"
        pause
        return 1
    fi
    
    # Check if updates are available
    if ! read_update_state || [[ "${UPDATES_AVAILABLE:-false}" != "true" ]]; then
        clear_screen "Apply Updates"
        log_warning "No updates available"
        echo
        show_info "Action" "Run 'Check Now' first"
        echo
        pause
        return 0
    fi
    
    clear_screen "Apply Updates"
    
    # Run update script (it handles confirmation)
    "$UPDATE_SCRIPT"
    
    echo
}

# Interactive updates menu
updates_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"
    
    while true; do
        clear_screen "Dotfiles Updates"
        
        # Show current status
        local has_updates=false
        if read_update_state; then
            if [[ "${UPDATES_AVAILABLE:-false}" == "true" ]] && [[ "${COMMIT_COUNT:-0}" -gt 0 ]]; then
                show_quick_summary "Status" "🔄 Updates available"
                has_updates=true
            elif [[ "${UPDATES_AVAILABLE:-false}" == "error" ]]; then
                show_quick_summary "Status" "⚠️  Error checking updates"
            else
                show_quick_summary "Status" "✅ Up to date"
            fi
        else
            show_quick_summary "Status" "❓ Not checked yet"
        fi
        
        # Build menu options based on update availability
        local options=("Check Now")
        if [[ "$has_updates" == "true" ]]; then
            options+=("Apply Updates")
        fi
        options+=("Show Details" "Back")
        
        local action=$(choose_option "${options[@]}")
        
        [[ -z "$action" ]] && return  # ESC pressed
        
        case "$action" in
            "Check Now")
                run_operation "" updates_check
                ;;
            "Apply Updates")
                run_operation "" updates_apply
                ;;
            "Show Details")
                run_operation "" updates_status
                ;;
            "Back")
                return
                ;;
        esac
    done
}

