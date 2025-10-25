#!/bin/bash
# Presentation helpers - colors, formatting, gum integration

# Ensure gum is available (install if needed)
ensure_gum() {
    if ! command -v gum &>/dev/null; then
        echo "Installing gum for better UI..."
        sudo pacman -S --needed --noconfirm gum
    fi
}

# Colors (fallback if gum not available)
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export PURPLE='\033[0;35m'
export GRAY='\033[0;90m'
export NC='\033[0m'

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

# Logging functions
log_info() {
    if command -v gum &>/dev/null; then
        gum style --foreground 12 "ℹ  $1"
    else
        echo -e "${BLUE}ℹ  $1${NC}"
    fi
}

log_success() {
    if command -v gum &>/dev/null; then
        gum style --foreground 10 "✓ $1"
    else
        echo -e "${GREEN}✓ $1${NC}"
    fi
}

log_warning() {
    if command -v gum &>/dev/null; then
        gum style --foreground 11 "⚠ $1"
    else
        echo -e "${YELLOW}⚠ $1${NC}"
    fi
}

log_error() {
    if command -v gum &>/dev/null; then
        gum style --foreground 9 "✗ $1"
    else
        echo -e "${RED}✗ $1${NC}"
    fi
}

log_section() {
    if command -v gum &>/dev/null; then
        echo
        gum style --bold --foreground 13 "$1"
        echo
    else
        echo
        echo -e "${PURPLE}━━━ $1 ━━━${NC}"
        echo
    fi
}

# Progress spinner
run_with_spinner() {
    local title="$1"
    shift
    
    if command -v gum &>/dev/null; then
        gum spin --spinner dot --title "$title" -- "$@"
    else
        echo -e "${BLUE}⟳ $title${NC}"
        "$@"
    fi
}

# Confirmation prompt
confirm() {
    local prompt="$1"
    local default="${2:-true}"
    
    if command -v gum &>/dev/null; then
        if [[ "$default" == "true" ]]; then
            gum confirm "$prompt"
        else
            gum confirm --default=false "$prompt"
        fi
    else
        local default_text="Y/n"
        [[ "$default" == "false" ]] && default_text="y/N"
        
        read -p "$prompt ($default_text): " -n 1 -r
        echo
        if [[ "$default" == "true" ]]; then
            [[ ! $REPLY =~ ^[Nn]$ ]]
        else
            [[ $REPLY =~ ^[Yy]$ ]]
        fi
    fi
}

# Input prompt
get_input() {
    local prompt="$1"
    local placeholder="${2:-}"
    
    if command -v gum &>/dev/null; then
        if [[ -n "$placeholder" ]]; then
            gum input --placeholder "$placeholder" --prompt "$prompt "
        else
            gum input --prompt "$prompt "
        fi
    else
        read -p "$prompt: " input
        echo "$input"
    fi
}

# Menu selection with consistent styling
choose_option() {
    if command -v gum &>/dev/null; then
        gum choose --header "" --height 15 --cursor.foreground 212 "$@"
    else
        local options=("$@")
        select opt in "${options[@]}"; do
            if [[ -n "$opt" ]]; then
                echo "$opt"
                break
            fi
        done
    fi
}

# Multi-select menu
choose_option_multi() {
    if command -v gum &>/dev/null; then
        gum choose --no-limit --height 15 --cursor.foreground 212 "$@"
    else
        echo "$@"
    fi
}

# Clear screen with optional header
clear_screen() {
    clear
    if [[ -n "${1:-}" ]]; then
        if command -v gum &>/dev/null; then
            gum style --bold --foreground 212 "$1"
            echo
        else
            echo -e "${PURPLE}$1${NC}"
            echo
        fi
    fi
}

# Show key-value pairs
show_info() {
    local key="$1"
    local value="$2"

    if command -v gum &>/dev/null; then
        echo "$(gum style --foreground 240 "$key:")  $(gum style --foreground 15 "$value")"
    else
        echo -e "${GRAY}$key:${NC} $value"
    fi
}

# Run command with clean UI: header + muted boxed output
run_with_clean_ui() {
    local title="$1"
    local command="$2"

    if command -v gum &>/dev/null; then
        # Show header with border
        gum style \
            --border double \
            --border-foreground 212 \
            --padding "0 2" \
            --bold \
            "$title"
        echo

        # Show muted "Output:" label
        gum style --foreground 240 "Output:"
        echo

        # Run command and show output as faint/muted
        eval "$command" 2>&1 | while IFS= read -r line; do
            gum style --faint "  $line"
        done

        echo
    else
        # Fallback without gum
        echo "━━━ $title ━━━"
        echo
        eval "$command"
        echo
    fi
}

# Run command with spinner and scrolling output
run_with_spinner_box() {
    local title="$1"
    local command="$2"
    local max_lines="${3:-15}"  # Show last 15 lines by default

    if command -v gum &>/dev/null; then
        # Use gum spin with output shown
        gum spin --spinner dot --title "$title" --show-output -- bash -c "$command"
    else
        # Fallback without gum
        echo "⟳ $title"
        echo "─────────────────────────────"
        eval "$command"
        echo "─────────────────────────────"
    fi
}

