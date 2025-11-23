#!/bin/bash
# Presentation helpers - gum-powered UI components
# Requires: gum (charmbracelet/gum)

# Configure gum to use base16 colors for navigation hints and logging
# Uses base03 (muted/comments) for help text to match theme
configure_gum_colors() {
    local dotfiles_dir="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
    local schemes_dir="$dotfiles_dir/stow/flavours/.config/flavours/schemes"
    
    # Get current scheme from flavours
    local current_scheme="none"
    if command -v flavours &>/dev/null || [[ -x "$HOME/.cargo/bin/flavours" ]]; then
        local flavours_cmd="flavours"
        [[ ! -x "$(command -v flavours)" ]] && flavours_cmd="$HOME/.cargo/bin/flavours"
        current_scheme=$("$flavours_cmd" current 2>/dev/null || echo "none")
    fi
    
    # Find scheme file
    local scheme_file=""
    if [[ "$current_scheme" != "none" ]] && [[ -n "$current_scheme" ]]; then
        [[ -f "$schemes_dir/$current_scheme/$current_scheme.yaml" ]] && scheme_file="$schemes_dir/$current_scheme/$current_scheme.yaml"
    fi
    [[ -z "$scheme_file" ]] && [[ -f "$schemes_dir/default/default.yaml" ]] && scheme_file="$schemes_dir/default/default.yaml"
    [[ -z "$scheme_file" ]] && scheme_file=$(find "$schemes_dir" -name "*.yaml" -type f 2>/dev/null | head -1)
    
    # Note: gum log handles level colors automatically (INFO=blue, WARN=yellow, ERROR=red)
    # We let gum log use its defaults for consistent, readable output
    
    # Use green color scheme (base0B) as the single accent color
    # ANSI color 2 is green (base0B) in most themes
    # Gum only accepts ANSI color codes (0-15), not hex colors
    export GUM_CHOOSE_CURSOR_FOREGROUND="2"  # Cursor color (the ">" indicator) - green
    export GUM_CHOOSE_CURSOR_BACKGROUND=""
    export GUM_CHOOSE_HELP_FOREGROUND="2"    # Help text color - green
    export GUM_CHOOSE_HELP_BACKGROUND=""
    export GUM_FILTER_HELP_FOREGROUND="8"
    export GUM_FILTER_HELP_BACKGROUND=""
    export GUM_CONFIRM_HELP_FOREGROUND="8"
    export GUM_CONFIRM_HELP_BACKGROUND=""
    export GUM_INPUT_HELP_FOREGROUND="8"
    export GUM_INPUT_HELP_BACKGROUND=""
    export GUM_WRITE_HELP_FOREGROUND="8"
    export GUM_WRITE_HELP_BACKGROUND=""
}

# Initialize gum colors on load
configure_gum_colors

# Centered box UI helpers
export BOX_WIDTH=70

get_terminal_dimensions() {
    export TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
    export TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
}

box_padding() {
    local box_padding=$(( (TERM_WIDTH - BOX_WIDTH) / 2 ))
    [[ $box_padding -lt 0 ]] && box_padding=0
    echo "$box_padding"
}

box_line() {
    local padding=$(box_padding)
    printf "%*s%s\n" $padding "" "$1"
}

center_in_box() {
    local text="$1"
    local padding=$(box_padding)
    local content_width=$((BOX_WIDTH - 4))
    local text_padding=$(( (content_width - ${#text}) / 2 ))
    [[ $text_padding -lt 0 ]] && text_padding=0
    printf "%*s│ %*s%s%*s │\n" $padding "" $text_padding "" "$text" $((content_width - text_padding - ${#text})) ""
}

left_in_box() {
    local text="$1"
    local padding=$(box_padding)
    local content_width=$((BOX_WIDTH - 4))
    local remaining=$((content_width - ${#text}))
    [[ $remaining -lt 0 ]] && remaining=0
    printf "%*s│ %s%*s │\n" $padding "" "$text" $remaining ""
}

box_empty() {
    box_line "│$(printf ' %.0s' {1..68})│"
}

box_top() {
    box_line "╭$(printf '─%.0s' {1..68})╮"
}

box_bottom() {
    box_line "╰$(printf '─%.0s' {1..68})╯"
}

box_divider() {
    box_line "├$(printf '─%.0s' {1..68})┤"
}

vertical_center() {
    local content_lines="$1"
    get_terminal_dimensions
    local padding_top=$(( (TERM_HEIGHT - content_lines) / 2 ))
    [[ $padding_top -lt 0 ]] && padding_top=0
    for ((i = 0; i < padding_top; i++)); do echo; done
}

# Logging functions using gum log for consistent structured logging
log_info() {
    # Show info message without INFO prefix for cleaner status displays
    echo "$*"
}

log_success() {
    # Show success message in green without INFO prefix
    # Messages can include their own checkmarks if needed
    gum style --foreground 2 "$*"  # base0B green
}

log_warning() {
    gum log --level warn "$@"
}

log_error() {
    gum log --level error "$@"
}

log_section() {
    # Keep bold styling for sections for visual distinction
    gum style --bold "$@"
    echo
}

# Status indicator helpers (for inline use in status displays)
status_ok() {
    gum style --foreground 2 "✓"  # base0B green
}

status_error() {
    gum style --foreground 1 "✗"  # base08 red
}

status_warning() {
    gum style --foreground 3 "○"  # base0A yellow
}

status_neutral() {
    gum style --foreground 8 "○"  # base03 muted
}

status_info() {
    gum style --foreground 4 "ℹ"  # base0D blue
}

# Progress spinner
run_with_spinner() {
    local title="$1"
    shift
    gum spin --spinner dot --title "$title" -- "$@"
}

# Confirmation and input functions are now in lib/common.sh
# These are kept as aliases for backward compatibility
# They will be overridden by lib/common.sh when sourced

# Menu selection (uses terminal theme colors)
# Usage: choose_option [--header "Header text"] [--selected "item"] [options...]
choose_option() {
    local header=""
    local selected=""
    local args=()

    # Parse optional flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --header)
                header="$2"
                shift 2
                ;;
            --selected)
                selected="$2"
                shift 2
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    # Build command
    local cmd=(gum choose --no-show-help)
    [[ -n "$header" ]] && cmd+=(--header "$header") || cmd+=(--header "")
    [[ -n "$selected" ]] && cmd+=(--selected "$selected")
    cmd+=("${args[@]}")
    
    "${cmd[@]}"
}

# Fuzzy filter search (for large lists)
# Usage: selected=$(filter_search "placeholder text" [--limit N] < items.txt)
filter_search() {
    local placeholder="${1:-Search...}"
    shift

    local limit_flag="--no-limit"
    local args=()

    # Parse optional flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit)
                limit_flag="--limit $2"
                shift 2
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    gum filter $limit_flag --placeholder "$placeholder" "${args[@]}"
}

# Display table from CSV data
# Usage: show_table < data.csv  OR  echo "header,data" | show_table
show_table() {
    gum table
}

# Clear screen with optional header
clear_screen() {
    # Clear screen AND scrollback buffer for clean display
    clear && printf '\033[3J'
    # Move cursor to top-left
    tput cup 0 0 2>/dev/null || true

    if [[ -n "${1:-}" ]]; then
        gum style --bold "$1"
        echo
    fi
}

# Show key-value pairs
show_info() {
    local key="$1"
    local value="$2"
    echo "$(gum style --bold --foreground 2 "$key:") $(gum style "$value")"  # base03 muted for key
}

# Run command with clean UI: header + muted boxed output
run_with_clean_ui() {
    local title="$1"
    local command="$2"

    # Show header with border (Base16 purple)
    gum style \
        --border double \
        --border-foreground 5 \
        --padding "0 2" \
        --bold \
        "$title"
    echo

    # Show muted "Output:" label
    gum style --foreground 8 "Output:"  # base03
    echo

    # Run command and show output as faint/muted
    eval "$command" 2>&1 | while IFS= read -r line; do
        gum style --faint "  $line"
    done

    echo
}

# Run command with full output (no spinner, just like FULL INSTALL)
run_with_spinner_box() {
    local title="$1"
    local command="$2"

    # Just execute the command and show raw output
    bash -c "$command"
}

# =============================================================================
# Helper Wrappers - Reduce Boilerplate
# =============================================================================

# Run operation with automatic status display
# Usage: run_op "message" command [args...]
run_op() {
    local message="$1"
    shift

    log_info "$message"
    echo

    "$@"
    local exit_code=$?

    echo

    if [[ $exit_code -eq 0 ]]; then
        log_success "Complete"
    else
        log_error "Failed (exit code: $exit_code)"
    fi

    return $exit_code
}

# Run operation with spinner
# Usage: run_with_spin "message" command [args...]
run_with_spin() {
    local message="$1"
    shift
    gum spin --spinner dot --title "$message" -- "$@"
}

# Pause for user input
# Usage: pause [message]
pause() {
    local message="${1:-Press any key to continue...}"
    echo
    read -p "$message " -n 1 -r
    echo
}

