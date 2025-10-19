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
    
    # Create log file if it doesn't exist
    touch "$DOTFILES_LOG_FILE" 2>/dev/null || {
        log_warning "Could not create log file: $DOTFILES_LOG_FILE"
        return 1
    }
    
    # Write session start marker
    echo "" >> "$DOTFILES_LOG_FILE"
    echo "=== Session started: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$DOTFILES_LOG_FILE"
    
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

# Run a command with logging
run_logged() {
    local script="$1"
    shift
    local args=("$@")
    
    log_info "Running: $(basename "$script")"
    log_to_file "INFO" "Starting: $script ${args[*]}"
    
    # Run the script and show output to screen + log file
    if bash "$script" "${args[@]}" 2>&1 | tee -a "$DOTFILES_LOG_FILE"; then
        log_to_file "SUCCESS" "Completed: $script"
        return 0
    else
        local exit_code=${PIPESTATUS[0]}
        log_to_file "ERROR" "Failed: $script (exit code: $exit_code)"
        return $exit_code
    fi
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

