#!/bin/bash
# Error handling helpers

# Track if we're in an error state
export DOTFILES_ERROR_STATE=false

cleanup_install() {
    local status=$?
    trap - EXIT ERR INT TERM
    stop_log_monitor true
    if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
        terminate_process_tree "$SUDO_KEEPALIVE_PID"
        wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
    if (( status != 0 )); then
        if [[ "${DOTFILES_INSTALL_STATE_READY:-false}" == "true" ]] && command -v jq &>/dev/null && load_state; then
            local phase
            phase=$(get_state current_phase)
            if [[ "$(get_state status)" != "failed" ]]; then
                fail_phase "$phase" "Installer exited with status $status"
            fi
        fi
        log_error "Installation stopped (exit $status). Completed work is saved."
        log_info "Retry: $DOTFILES_DIR/install.sh --resume"
    fi
    show_log_location
    finish_logging
    exit "$status"
}

# Error handler
handle_error() {
    local exit_code=$?
    local line_number="${1:-unknown}"
    local command="${2:-unknown}"
    
    DOTFILES_ERROR_STATE=true
    
    log_error "Command failed with exit code $exit_code"
    if [[ "$line_number" != "unknown" ]]; then
        log_error "Line: $line_number"
    fi
    if [[ "$command" != "unknown" ]]; then
        log_error "Command: $command"
    fi
    
    # Log to file if available
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Exit code $exit_code at line $line_number: $command" >> "$DOTFILES_LOG_FILE"
    fi
}

# Children first, so a parent cannot respawn a child that was just killed.
# Walks the tree instead of killing the process group: install.sh is not a
# group leader when run over ssh or from another script, and killing that
# group would take down the caller too.
terminate_process_tree() {
    local root_pid="$1"
    local child_pid

    for child_pid in $(pgrep -P "$root_pid"); do
        terminate_process_tree "$child_pid"
    done

    if [[ "$root_pid" != "$$" ]]; then
        kill -TERM "$root_pid" 2>/dev/null || true
    fi
}

# Ctrl+C reaches the foreground group, but yay and makepkg spawn builds that
# outlive it (a stranded gtk2 `makepkg -F` ran on for 12 minutes).
handle_install_interrupt() {
    trap - INT TERM ERR
    stop_log_monitor
    terminate_process_tree "$$"
    echo "Installation interrupted" >&2
    exit 130
}

# Set up error trapping
setup_error_handling() {
    set -E  # Inherit ERR trap in functions
    trap 'handle_error "${BASH_SOURCE[0]}:${LINENO}" "$BASH_COMMAND"' ERR
}

# Graceful error - don't exit, just log and continue
graceful_error() {
    local message="$1"
    local suggestion="${2:-}"
    
    log_error "$message"
    if [[ -n "$suggestion" ]]; then
        log_info "Suggestion: $suggestion"
    fi
    
    DOTFILES_ERROR_STATE=true
    
    # Log to file
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $message" >> "$DOTFILES_LOG_FILE"
        [[ -n "$suggestion" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUGGESTION: $suggestion" >> "$DOTFILES_LOG_FILE"
    fi
}

# Fatal error - show message and exit
fatal_error() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log_error "Fatal: $message"
    
    # Log to file
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] FATAL: $message" >> "$DOTFILES_LOG_FILE"
    fi
    
    exit "$exit_code"
}

# Check if command exists
require_command() {
    local command="$1"
    local package="${2:-$1}"
    
    if ! command -v "$command" &>/dev/null; then
        graceful_error "Required command not found: $command" \
            "Install with: sudo pacman -S $package"
        return 1
    fi
    return 0
}

# Check if file exists
require_file() {
    local file="$1"
    local description="${2:-file}"
    
    if [[ ! -f "$file" ]]; then
        graceful_error "Required $description not found: $file"
        return 1
    fi
    return 0
}

# Check if directory exists
require_directory() {
    local dir="$1"
    local description="${2:-directory}"
    
    if [[ ! -d "$dir" ]]; then
        graceful_error "Required $description not found: $dir"
        return 1
    fi
    return 0
}

# Ensure directory exists (create if needed)
ensure_directory() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            graceful_error "Failed to create directory: $dir"
            return 1
        }
    fi
    return 0
}

# Check for common issues
check_prerequisites() {
    local all_ok=true
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        graceful_error "Do not run as root. Use sudo only when needed."
        all_ok=false
    fi
    
    # Check internet connection (for package installs)
    # Use timeout + ping to IP address to avoid DNS resolution hangs
    if timeout 3 ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
        : # Connection OK
    else
        log_warning "No internet connection detected"
        log_info "Some operations may fail"
    fi
    
    # Check if pacman is available
    if ! command -v pacman &>/dev/null; then
        graceful_error "pacman not found. Are you on Arch Linux?"
        all_ok=false
    fi
    
    $all_ok
}

