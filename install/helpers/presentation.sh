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

# Menu selection
choose_option() {
    if command -v gum &>/dev/null; then
        gum choose "$@"
    else
        # Fallback to simple menu
        local options=("$@")
        select opt in "${options[@]}"; do
            if [[ -n "$opt" ]]; then
                echo "$opt"
                break
            fi
        done
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

