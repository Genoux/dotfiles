#!/bin/bash
# Unified progress display for all operations
# Provides: spinner header + scrolling logs + full terminal scrollback

# Configuration
PROGRESS_REFRESH_RATE="${PROGRESS_REFRESH_RATE:-0.1}"

# State
PROGRESS_PID=""
PROGRESS_TITLE=""
PROGRESS_TERM_HEIGHT=""
PROGRESS_SCROLL_TOP=3

# Start progress display
# Usage: progress_start "Operation title"
progress_start() {
    local title="$1"

    # Ensure logging is initialized
    if [[ -z "${DOTFILES_LOG_FILE:-}" ]]; then
        init_logging "daily"
    fi

    export PROGRESS_TITLE="$title"
    export PROGRESS_TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
    local term_width=$(tput cols 2>/dev/null || echo 80)

    # Clear screen
    clear

    # Hide cursor
    tput civis 2>/dev/null || true

    # Set up scroll region (leave top 3 lines for header)
    # Line 1: Spinner + title
    # Line 2: Separator
    # Line 3+: Scrolling log area
    printf "\033[3;${PROGRESS_TERM_HEIGHT}r"

    # Print initial header (in non-scroll area)
    printf "\033[1;1H"
    printf "\033[97m⠋ %s\033[K\n" "$title"
    printf "\033[90m%s\033[K\n" "$(printf '─%.0s' $(seq 1 $term_width))"

    # Move to scroll region
    printf "\033[3;1H"

    # Start spinner updater in background
    (
        trap 'exit 0' TERM INT

        local spinners=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
        local idx=0
        local term_w=$(tput cols 2>/dev/null || echo 80)

        while true; do
            # Get current step from log
            local step=""
            if [[ -f "$DOTFILES_LOG_FILE" ]]; then
                step=$(grep -o "Starting: .*" "$DOTFILES_LOG_FILE" 2>/dev/null | tail -1 | sed 's/Starting: //' | sed 's/\.sh$//')
            fi
            [[ -z "$step" ]] && step="$PROGRESS_TITLE"

            # Truncate if too long
            local max_len=$((term_w - 4))
            [[ ${#step} -gt $max_len ]] && step="${step:0:$max_len}"

            # Update spinner at top (save cursor, move to line 1, update, restore)
            printf "\033[s\033[1;1H\033[97m%s %s\033[K\033[u" "${spinners[$idx]}" "$step"

            idx=$(( (idx + 1) % ${#spinners[@]} ))
            sleep "$PROGRESS_REFRESH_RATE"
        done
    ) &
    PROGRESS_PID=$!
}

# Stop progress display
# Usage: progress_stop [show_complete_message]
progress_stop() {
    local show_complete="${1:-false}"

    # Kill spinner updater and wait for it to fully exit
    if [[ -n "$PROGRESS_PID" ]]; then
        kill "$PROGRESS_PID" 2>/dev/null || true
        wait "$PROGRESS_PID" 2>/dev/null || true
        PROGRESS_PID=""
    fi

    # Small delay to ensure background process is fully dead
    sleep 0.1

    # Show cursor
    tput cnorm 2>/dev/null || true
}

# Run a command with output to both terminal and log file
# Usage: progress_run "Step name" command [args...]
progress_run() {
    local step_name="$1"
    shift
    local cmd=("$@")

    # Log start
    [[ -n "${DOTFILES_LOG_FILE:-}" ]] && \
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $step_name" >> "$DOTFILES_LOG_FILE"

    local exit_code=0

    # Run with unbuffered output, tee to log file
    if command -v stdbuf &>/dev/null; then
        stdbuf -oL -eL "${cmd[@]}" 2>&1 | while IFS= read -r line; do
            # Color-code output for visibility
            if [[ "$line" =~ ERROR|error|Failed|failed ]]; then
                printf "\033[91m%s\033[0m\n" "$line"
            elif [[ "$line" =~ WARN|warn|Warning|warning ]]; then
                printf "\033[93m%s\033[0m\n" "$line"
            elif [[ "$line" =~ ✓|Success|Complete|Completed ]]; then
                printf "\033[92m%s\033[0m\n" "$line"
            else
                printf "\033[90m%s\033[0m\n" "$line"  # Gray output
            fi
            # Append to log (strip ANSI codes)
            [[ -n "${DOTFILES_LOG_FILE:-}" ]] && \
                echo "$line" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' >> "$DOTFILES_LOG_FILE"
        done
        exit_code=${PIPESTATUS[0]}
    else
        "${cmd[@]}" 2>&1 | while IFS= read -r line; do
            if [[ "$line" =~ ERROR|error|Failed|failed ]]; then
                printf "\033[91m%s\033[0m\n" "$line"
            elif [[ "$line" =~ WARN|warn|Warning|warning ]]; then
                printf "\033[93m%s\033[0m\n" "$line"
            elif [[ "$line" =~ ✓|Success|Complete|Completed ]]; then
                printf "\033[92m%s\033[0m\n" "$line"
            else
                printf "\033[90m%s\033[0m\n" "$line"  # Gray output
            fi
            [[ -n "${DOTFILES_LOG_FILE:-}" ]] && \
                echo "$line" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' >> "$DOTFILES_LOG_FILE"
        done
        exit_code=${PIPESTATUS[0]}
    fi

    # Log completion
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        if [[ $exit_code -eq 0 ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $step_name" >> "$DOTFILES_LOG_FILE"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $step_name (exit code: $exit_code)" >> "$DOTFILES_LOG_FILE"
        fi
    fi

    return $exit_code
}

# Run a script with full logging (redirects all output to log)
# For scripts that handle their own output
# Usage: progress_run_script "script.sh" [args...]
progress_run_script() {
    local script="$1"
    shift
    local args=("$@")
    local script_name=$(basename "$script" .sh)

    # Log start
    [[ -n "${DOTFILES_LOG_FILE:-}" ]] && \
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $script_name" >> "$DOTFILES_LOG_FILE"

    local exit_code=0

    # Run script with output to both terminal and log
    if command -v stdbuf &>/dev/null; then
        stdbuf -oL -eL bash "$script" "${args[@]}" 2>&1 | while IFS= read -r line; do
            # Color-code output for visibility
            if [[ "$line" =~ ERROR|error|Failed|failed ]]; then
                printf "\033[91m%s\033[0m\n" "$line"
            elif [[ "$line" =~ WARN|warn|Warning|warning ]]; then
                printf "\033[93m%s\033[0m\n" "$line"
            elif [[ "$line" =~ ✓|Success|Complete|Completed ]]; then
                printf "\033[92m%s\033[0m\n" "$line"
            else
                printf "\033[90m%s\033[0m\n" "$line"  # Gray output
            fi
            # Log without colors
            [[ -n "${DOTFILES_LOG_FILE:-}" ]] && \
                echo "$line" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' >> "$DOTFILES_LOG_FILE"
        done
        exit_code=${PIPESTATUS[0]}
    else
        bash "$script" "${args[@]}" 2>&1 | while IFS= read -r line; do
            if [[ "$line" =~ ERROR|error|Failed|failed ]]; then
                printf "\033[91m%s\033[0m\n" "$line"
            elif [[ "$line" =~ WARN|warn|Warning|warning ]]; then
                printf "\033[93m%s\033[0m\n" "$line"
            elif [[ "$line" =~ ✓|Success|Complete|Completed ]]; then
                printf "\033[92m%s\033[0m\n" "$line"
            else
                printf "\033[90m%s\033[0m\n" "$line"  # Gray output
            fi
            [[ -n "${DOTFILES_LOG_FILE:-}" ]] && \
                echo "$line" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' >> "$DOTFILES_LOG_FILE"
        done
        exit_code=${PIPESTATUS[0]}
    fi

    # Log completion
    if [[ -n "${DOTFILES_LOG_FILE:-}" ]]; then
        if [[ $exit_code -eq 0 ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $script_name" >> "$DOTFILES_LOG_FILE"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $script_name (exit code: $exit_code)" >> "$DOTFILES_LOG_FILE"
        fi
    fi

    return $exit_code
}

# Show completion screen with options
# Usage: progress_complete [title]
progress_complete() {
    local title="${1:-Operation}"

    # Ensure spinner is stopped
    progress_stop false

    # Extra delay to ensure spinner is fully dead
    sleep 0.2

    # Reset scroll region
    printf "\033[r"

    # Clear entire screen
    clear

    # Show cursor
    tput cnorm 2>/dev/null || true

    # Show completion message
    echo
    printf "\033[92m✓ %s complete\033[0m\n" "$title"
    printf "\n"

    while true; do
        # Show menu
        printf "\033[97m[R] Reboot  [Q] Continue\033[0m\n"

        read -rsn1 key

        # Move cursor up to menu line to redraw on next iteration
        printf "\033[1A\r\033[K"
        case "${key,,}" in
            r)
                clear
                echo
                printf "\033[94mRebooting...\033[0m\n"
                sudo systemctl reboot
                ;;
            q|$'\n'|'')
                clear
                break
                ;;
        esac
    done
}

# Cleanup handler - call this in trap
progress_cleanup() {
    # Kill spinner if running
    if [[ -n "$PROGRESS_PID" ]]; then
        kill "$PROGRESS_PID" 2>/dev/null || true
        wait "$PROGRESS_PID" 2>/dev/null || true
        PROGRESS_PID=""
        sleep 0.1  # Ensure fully dead
    fi

    # Reset scroll region
    printf "\033[r"

    # Show cursor
    tput cnorm 2>/dev/null || true
}
