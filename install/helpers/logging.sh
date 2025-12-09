#!/bin/bash
# Logging infrastructure

# Log file locations
export DOTFILES_LOG_DIR="$HOME/.local/state/dotfiles"
export DOTFILES_INSTALL_LOG="$DOTFILES_LOG_DIR/install.log"
export DOTFILES_DAILY_LOG="$DOTFILES_LOG_DIR/dotfiles.log"

# Initialize logging
init_logging() {
    local log_type="${1:-daily}"  # install or daily
    
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
    
    # Export start time
    export DOTFILES_SESSION_START=$(date +%s)
}

# Log a message to file
log_to_file() {
    local level="$1"
    local message="$2"
    
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$DOTFILES_LOG_FILE"
    fi
}

# Start live log monitor (improved with better scrolling)
start_log_monitor() {
    # Get terminal dimensions
    local term_height=$(tput lines 2>/dev/null || echo 24)
    local term_width=$(tput cols 2>/dev/null || echo 80)
    local log_lines=$((term_height - 4))  # More space for logs

    # Use alternate screen and hide cursor
    tput smcup 2>/dev/null
    tput civis 2>/dev/null  # Hide cursor
    clear

    (
        # Disable error handling in monitor subprocess
        set +eEo pipefail

        local spinners=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
        local spinner_index=0

        # Store previous log content to detect changes
        local prev_log_content=""
        local prev_log_lines=0
        
        while true; do
            # Get current step
            local current_step=$(grep -o "Starting: .*" "$DOTFILES_LOG_FILE" 2>/dev/null | tail -1 | sed 's/Starting: //' | sed 's/\.sh$//' || echo "dotfiles")

            # Get current log content
            local current_log_content=""
            if [[ -f "$DOTFILES_LOG_FILE" ]]; then
                current_log_content=$(tail -n $log_lines "$DOTFILES_LOG_FILE" 2>/dev/null)
            fi
            local current_log_lines=$(echo "$current_log_content" | wc -l)

            # Only redraw if content changed or first run
            if [[ "$current_log_content" != "$prev_log_content" ]] || [[ $prev_log_lines -eq 0 ]]; then
                # Clear screen only when content changes
                tput cup 0 0 2>/dev/null
                tput ed 2>/dev/null

                # Print spinner line (white)
                local status_line="${spinners[$spinner_index]} Installing ${current_step}..."
                if [ ${#status_line} -gt $term_width ]; then
                    status_line="${status_line:0:$term_width}"
                fi
                printf "\033[97m%s\033[0m\n" "$status_line"

                # Show help text
                printf "\033[90mPress Ctrl+C to stop installation\033[0m\n"
                echo

                # Print log lines with better formatting
                echo "$current_log_content" | while IFS= read -r line; do
                    # Highlight package-related lines in blue for better visibility
                    if [[ "$line" =~ \[PACMAN\]|\[YAY\] ]]; then
                        printf "\033[94m%s\033[0m\n" "${line:0:$term_width}"
                    elif [[ "$line" =~ Starting:|Completed:|Failed: ]]; then
                        printf "\033[92m%s\033[0m\n" "${line:0:$term_width}"
                    else
                        printf "\033[90m%s\033[0m\n" "${line:0:$term_width}"
                    fi
                done

                # Update previous content
                prev_log_content="$current_log_content"
                prev_log_lines=$current_log_lines
            else
                # Just update spinner position without redrawing
                tput cup 0 0 2>/dev/null
                local status_line="${spinners[$spinner_index]} Installing ${current_step}..."
                if [ ${#status_line} -gt $term_width ]; then
                    status_line="${status_line:0:$term_width}"
                fi
                printf "\033[97m%s\033[0m" "$status_line"
                tput el 2>/dev/null  # Clear to end of line
            fi

            # Next spinner
            spinner_index=$(( (spinner_index + 1) % ${#spinners[@]} ))
            sleep "${DOTFILES_LOG_REFRESH_RATE:-0.1}"  # Configurable refresh rate (default: 0.1s)
        done
    ) &
    export DOTFILES_LOG_MONITOR_PID=$!
}

# Stop live log monitor
stop_log_monitor() {
    local keep_visible="${1:-false}"

    if [ -n "${DOTFILES_LOG_MONITOR_PID:-}" ]; then
        kill $DOTFILES_LOG_MONITOR_PID 2>/dev/null || true
        wait $DOTFILES_LOG_MONITOR_PID 2>/dev/null || true
        unset DOTFILES_LOG_MONITOR_PID
    fi

    # Restore terminal
    tput cnorm 2>/dev/null  # Show cursor
    tput rmcup 2>/dev/null  # Exit alternate screen

    # If keep_visible, show the full log with colors (scrollable)
    if [[ "$keep_visible" == "true" ]] && [[ -f "$DOTFILES_LOG_FILE" ]]; then
        clear
        # Display entire log with colors - terminal scrollback allows scrolling up
        while IFS= read -r line; do
            # Highlight package-related lines in blue
            if [[ "$line" =~ \[PACMAN\]|\[YAY\] ]]; then
                printf "\033[94m%s\033[0m\n" "$line"
            elif [[ "$line" =~ Starting:|Completed:|Failed: ]]; then
                printf "\033[92m%s\033[0m\n" "$line"
            elif [[ "$line" =~ ===.*=== ]]; then
                printf "\033[1m%s\033[0m\n" "$line"
            else
                printf "\033[90m%s\033[0m\n" "$line"
            fi
        done < "$DOTFILES_LOG_FILE"
        echo
    else
        clear
    fi
}

# Run a command with logging
run_logged() {
    local script="$1"
    shift
    local args=("$@")

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $script" >> "$DOTFILES_LOG_FILE"

    # Run script with unbuffered output for real-time log updates
    # Use stdbuf to disable buffering, or fall back to regular redirect
    if command -v stdbuf &>/dev/null; then
        # Force line buffering for better real-time output
        stdbuf -oL -eL bash "$script" "${args[@]}" </dev/null >> "$DOTFILES_LOG_FILE" 2>&1
        local exit_code=$?
    else
        # Fallback: use script command for pseudo-terminal (forces unbuffered output)
        script -q -c "bash '$script' ${args[*]}" /dev/null >> "$DOTFILES_LOG_FILE" 2>&1
        local exit_code=$?
    fi

    if [ $exit_code -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $script" >> "$DOTFILES_LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $script (exit code: $exit_code)" >> "$DOTFILES_LOG_FILE"
    fi

    return $exit_code
}

# Run a command with real-time logging and ANSI stripping
run_command_logged() {
    local step_name="$1"
    shift
    local command=("$@")

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $step_name" >> "$DOTFILES_LOG_FILE"

    local exit_code=0

    # Use stdbuf for unbuffered output and sed to strip ANSI escape codes
    # Redirect stdin from /dev/null to ensure commands run non-interactively
    if command -v stdbuf &>/dev/null; then
        stdbuf -oL -eL "${command[@]}" < /dev/null 2>&1 | sed -u 's/\x1b\[[0-9;]*[a-zA-Z]//g' >> "$DOTFILES_LOG_FILE" || exit_code=$?
    else
        # Fallback: use script with col to strip control characters
        script -q -e -c "${command[*]}" /dev/null < /dev/null 2>&1 | col -b >> "$DOTFILES_LOG_FILE" || exit_code=$?
    fi

    if [ $exit_code -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $step_name" >> "$DOTFILES_LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $step_name (exit code: $exit_code)" >> "$DOTFILES_LOG_FILE"
    fi

    return $exit_code
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

