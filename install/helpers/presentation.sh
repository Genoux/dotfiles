#!/bin/bash
# Presentation helpers - gum-powered UI components
# Requires: gum (charmbracelet/gum)

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

# Logging functions (Base16 ANSI colors)
log_info() {
    gum style --foreground 4 "ℹ  $1"  # base0D blue
}

log_success() {
    gum style --foreground 2 "✓ $1"  # base0B green
}

log_warning() {
    gum style --foreground 3 "⚠ $1"  # base0A yellow
}

log_error() {
    gum style --foreground 1 "✗ $1"  # base08 red
}

log_section() {
    echo
    gum style --bold --foreground 5 "$1"  # base0E purple
    echo
}

# Progress spinner
run_with_spinner() {
    local title="$1"
    shift
    gum spin --spinner dot --title "$title" -- "$@"
}

# Confirmation prompt
confirm() {
    local prompt="$1"
    local default="${2:-true}"

    if [[ "$default" == "true" ]]; then
        gum confirm "$prompt"
    else
        gum confirm --default=false "$prompt"
    fi
}

# Input prompt
get_input() {
    local prompt="$1"
    local placeholder="${2:-}"

    if [[ -n "$placeholder" ]]; then
        gum input --placeholder "$placeholder" --prompt "$prompt "
    else
        gum input --prompt "$prompt "
    fi
}

# Menu selection (uses terminal theme colors)
choose_option() {
    gum choose --header "" --height 15 "$@"
}

# Multi-select menu
choose_option_multi() {
    gum choose --no-limit --height 15 "$@"
}

# Fuzzy filter search (for large lists)
# Usage: selected=$(filter_search "placeholder text" < items.txt)
filter_search() {
    local placeholder="${1:-Search...}"
    gum filter --no-limit --placeholder "$placeholder"
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
        gum style --bold --foreground 5 "$1"  # base0E purple
        echo
    fi
}

# Show key-value pairs
show_info() {
    local key="$1"
    local value="$2"
    echo "$(gum style --foreground 8 "$key:")  $(gum style "$value")"  # base03 muted for key
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

# Run command with spinner and scrolling output
run_with_spinner_box() {
    local title="$1"
    local command="$2"

    gum spin --spinner dot --title "$title" --show-output -- bash -c "$command"
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

