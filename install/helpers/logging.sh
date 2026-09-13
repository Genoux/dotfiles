#!/bin/bash
# Logging infrastructure

# Log file locations
export DOTFILES_LOG_DIR="$HOME/.local/state/dotfiles"
export DOTFILES_INSTALL_LOG="$DOTFILES_LOG_DIR/install.log"
export DOTFILES_DAILY_LOG="$DOTFILES_LOG_DIR/dotfiles.log"

# Initialize logging
init_logging() {
    local log_type="${1:-daily}"  # install or daily

    # A session started by a parent process (install.sh) owns the log; nested
    # scripts run via run_logged must keep writing there, or the progress
    # screen freezes while their output lands in another, truncated file.
    # `dotfiles install` execs install.sh, which keeps $$, so it may re-init.
    if [[ -n "${DOTFILES_LOG_SESSION_PID:-}" && "$DOTFILES_LOG_SESSION_PID" != "$$" ]] \
        && kill -0 "$DOTFILES_LOG_SESSION_PID" 2>/dev/null; then
        return 0
    fi

    # Ensure log directory exists
    ensure_directory "$DOTFILES_LOG_DIR"
    
    # Set active log file
    if [[ "$log_type" == "install" ]]; then
        export DOTFILES_LOG_FILE="$DOTFILES_INSTALL_LOG"
    else
        export DOTFILES_LOG_FILE="$DOTFILES_DAILY_LOG"
    fi
    
    # Overwrite log file (fresh start each session)
    echo "=== Session started: $(date '+%Y-%m-%d %H:%M:%S') ===" > "$DOTFILES_LOG_FILE" 2>/dev/null || {
        log_warning "Could not create log file: $DOTFILES_LOG_FILE"
        return 1
    }
    
    export DOTFILES_SESSION_START=$(date +%s)
    export DOTFILES_LOG_SESSION_PID=$$
}

# Log a message to file
log_to_file() {
    local level="$1"
    local message="$2"
    
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$DOTFILES_LOG_FILE"
    fi
}

# Strip ANSI escapes and carriage-return redraws so the log stays plain text.
# pacman/yay/makepkg paint progress bars with \r; only the final state of each
# line is worth keeping.
strip_terminal_codes() {
    # LC_ALL=C: byte ranges like [@-~] silently match nothing under UTF-8 collation.
    LC_ALL=C sed -u -e 's/\x1b\[[0-9;?]*[ -/]*[@-~]//g' -e 's/\x1b[()][0-9A-Za-z]//g' -e 's/.*\r//'
}

# The monitor belongs to the process that started it. Scripts nested through
# run_logged inherit DOTFILES_LOG_MONITOR_PID and have stdout pointed at the log,
# so letting them start or stop a monitor would draw the screen into the log.
_owns_log_monitor() {
    [[ "${DOTFILES_LOG_MONITOR_OWNER:-}" == "$$" ]]
}

_log_monitor_running() {
    [[ -n "${DOTFILES_LOG_MONITOR_PID:-}" ]] && kill -0 "$DOTFILES_LOG_MONITOR_PID" 2>/dev/null
}

_render_log_monitor_frame() {
    local spinner="$1"
    local term_height term_width
    term_height=$(tput lines 2>/dev/null || echo 24)
    term_width=$(tput cols 2>/dev/null || echo 80)
    local visible_lines=$((term_height - 5))
    local text_width=$((term_width - 4))

    local current_step
    current_step=$(grep -o "Starting: .*" "$DOTFILES_LOG_FILE" 2>/dev/null | tail -1 | sed -e 's/^Starting: //' -e 's|.*/||' -e 's/\.sh$//')

    # printf -v, not $(...): command substitution drops the trailing newlines.
    local frame row log_line
    printf -v frame '\033[H\033[2K\n\033[2K  \033[1m%s\033[0m %s\n\033[2K\n' "$spinner" "${current_step:-Preparing}"
    while IFS= read -r log_line; do
        printf -v row '\033[2K  \033[90m%s\033[0m\n' "${log_line:0:$text_width}"
        frame+="$row"
    done < <(tail -n "$visible_lines" "$DOTFILES_LOG_FILE" 2>/dev/null | strip_terminal_codes)
    frame+=$'\033[J'

    printf '%s' "$frame"
}

start_log_monitor() {
    [[ -t 1 ]] || return 0
    _log_monitor_running && return 0

    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true
    clear

    (
        set +eEo pipefail
        trap - ERR

        local spinners=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
        local spinner_index=0
        while true; do
            _render_log_monitor_frame "${spinners[$spinner_index]}"
            spinner_index=$(((spinner_index + 1) % ${#spinners[@]}))
            sleep "${DOTFILES_LOG_REFRESH_RATE:-0.2}"
        done
    ) &
    export DOTFILES_LOG_MONITOR_PID=$!
    export DOTFILES_LOG_MONITOR_OWNER=$$
}

stop_log_monitor() {
    local show_log_tail="${1:-false}"

    _owns_log_monitor || return 0

    kill "$DOTFILES_LOG_MONITOR_PID" 2>/dev/null || true
    wait "$DOTFILES_LOG_MONITOR_PID" 2>/dev/null || true
    unset DOTFILES_LOG_MONITOR_PID DOTFILES_LOG_MONITOR_OWNER

    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true

    if [[ "$show_log_tail" == "true" ]] && [[ -f "$DOTFILES_LOG_FILE" ]]; then
        tail -n 30 "$DOTFILES_LOG_FILE" | strip_terminal_codes
        printf '\n\033[90mFull log: %s\033[0m\n' "$DOTFILES_LOG_FILE"
    fi
}

run_logged() {
    local script="$1"
    shift
    run_command_logged "$script" bash "$script" "$@"
}

run_command_logged() {
    local step_name="$1"
    shift

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $step_name" >> "$DOTFILES_LOG_FILE"

    # `|| true` keeps set -e/pipefail callers from exiting before the command's
    # own status is read from PIPESTATUS.
    local exit_code=0
    {
        stdbuf -oL -eL "$@" </dev/null 2>&1 | strip_terminal_codes >> "$DOTFILES_LOG_FILE"
        exit_code=${PIPESTATUS[0]}
    } || true

    if [ "$exit_code" -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $step_name" >> "$DOTFILES_LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $step_name (exit code: $exit_code)" >> "$DOTFILES_LOG_FILE"
    fi

    return "$exit_code"
}

# Finish logging session
finish_logging() {
    if [[ -n "${DOTFILES_SESSION_START:-}" && -n "${DOTFILES_LOG_FILE:-}" ]]; then
        local end_time=$(date +%s)
        local duration=$((end_time - DOTFILES_SESSION_START))
        local minutes=$((duration / 60))
        local seconds=$((duration % 60))
        
        echo "=== Session ended: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$DOTFILES_LOG_FILE"
        echo "=== Duration: ${minutes}m ${seconds}s ===" >> "$DOTFILES_LOG_FILE"
        echo "" >> "$DOTFILES_LOG_FILE"
    fi
}

# Show last N lines of log
show_log_tail() {
    local lines="${1:-20}"
    local log_file="${2:-$DOTFILES_LOG_FILE}"
    
    if [[ -f "$log_file" ]]; then
        log_section "Recent Log Entries"
        tail -n "$lines" "$log_file"
    else
        log_warning "Log file not found: $log_file"
    fi
}

# View full log with Gum pager (scrollable interface)
view_full_log() {
    local log_file="${1:-$DOTFILES_LOG_FILE}"
    
    if [[ ! -f "$log_file" ]]; then
        log_warning "Log file not found: $log_file"
        return 1
    fi
    
    if command -v gum &>/dev/null; then
        log_info "Opening log with Gum pager (scrollable interface)..."
        echo
        gum pager --show-line-numbers --soft-wrap "$log_file"
    else
        log_warning "Gum not available, showing last 50 lines:"
        echo
        tail -n 50 "$log_file"
    fi
}

# Show full log path
show_log_location() {
    if [[ -f "${DOTFILES_LOG_FILE:-}" ]]; then
        log_info "Log file: $DOTFILES_LOG_FILE"
    fi
}

# Rotate log files (keep last 5)
rotate_logs() {
    local log_file="$1"
    local keep_count="${2:-5}"
    
    if [[ ! -f "$log_file" ]]; then
        return 0
    fi
    
    # Check log size (rotate if > 10MB)
    local log_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
    if [[ $log_size -lt 10485760 ]]; then
        return 0
    fi
    
    # Rotate logs
    for i in $(seq $((keep_count - 1)) -1 1); do
        if [[ -f "$log_file.$i" ]]; then
            mv "$log_file.$i" "$log_file.$((i + 1))"
        fi
    done
    
    mv "$log_file" "$log_file.1"
    touch "$log_file"
    
    # Remove old logs
    for i in $(seq $((keep_count + 1)) 10); do
        rm -f "$log_file.$i"
    done
}

# Watch log in real-time (background process)
watch_log() {
    local log_file="${1:-$DOTFILES_LOG_FILE}"
    
    if [[ -f "$log_file" ]]; then
        tail -f "$log_file" &
        export DOTFILES_LOG_WATCHER=$!
    fi
}

# Stop log watcher
stop_log_watcher() {
    if [[ -n "${DOTFILES_LOG_WATCHER:-}" ]]; then
        kill "$DOTFILES_LOG_WATCHER" 2>/dev/null || true
        unset DOTFILES_LOG_WATCHER
    fi
}

