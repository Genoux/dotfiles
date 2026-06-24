#!/bin/bash
# Common utilities shared across all lib modules

# Get command version
# Usage: get_version command
get_version() {
    local cmd="$1"

    if ! command -v "$cmd" &>/dev/null; then
        echo "not installed"
        return 1
    fi

    case "$cmd" in
        zsh)
            zsh --version 2>/dev/null | cut -d' ' -f2
            ;;
        hyprctl)
            hyprctl version 2>/dev/null | head -1 | grep -oP 'Hyprland \K\d+\.\d+\.\d+' || echo "unknown"
            ;;
        node)
            node --version 2>/dev/null | sed 's/v//'
            ;;
        npm)
            npm --version 2>/dev/null
            ;;
        *)
            $cmd --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+(\.\d+)?' || echo "unknown"
            ;;
    esac
}

# Check if command exists
# Usage: has_command command
has_command() {
    command -v "$1" &>/dev/null
}

# Validate file exists
# Usage: require_file /path/to/file "File description"
require_file() {
    local file="$1"
    local description="${2:-File}"

    if [[ ! -f "$file" ]]; then
        fatal_error "$description not found: $file"
    fi
}

# Validate directory exists
# Usage: require_dir /path/to/dir "Directory description"
require_dir() {
    local dir="$1"
    local description="${2:-Directory}"

    if [[ ! -d "$dir" ]]; then
        fatal_error "$description not found: $dir"
    fi
}

# Safe source (source file only if it exists)
# Usage: safe_source /path/to/file
safe_source() {
    local file="$1"

    if [[ -f "$file" ]]; then
        source "$file"
        return 0
    else
        log_warning "File not found: $file"
        return 1
    fi
}

# Count lines in file (excluding comments and empty lines)
# Usage: count_items /path/to/file
count_items() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo 0
        return
    fi

    grep -cvE '^#|^$' "$file" 2>/dev/null || echo 0
}

# Check if string contains substring
# Usage: if contains "haystack" "needle"; then ...
contains() {
    [[ "$1" == *"$2"* ]]
}

# Trim whitespace
# Usage: trimmed=$(trim "  text  ")
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# Array contains element
# Usage: if array_contains "element" "${array[@]}"; then ...
array_contains() {
    local element="$1"
    shift
    local array=("$@")

    for item in "${array[@]}"; do
        [[ "$item" == "$element" ]] && return 0
    done

    return 1
}

# Get file modification time (seconds since epoch)
# Usage: mod_time=$(file_age /path/to/file)
file_age() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo 0
        return
    fi

    stat -c %Y "$file" 2>/dev/null || echo 0
}

# Check if file is older than N seconds
# Usage: if file_older_than /path/to/file 86400; then # 1 day
file_older_than() {
    local file="$1"
    local seconds="$2"

    if [[ ! -f "$file" ]]; then
        return 0  # Non-existent file is considered old
    fi

    local age=$(file_age "$file")
    local now=$(date +%s)
    local diff=$((now - age))

    [[ $diff -gt $seconds ]]
}

# Safely remove file/directory
# Usage: safe_remove /path/to/file_or_dir
safe_remove() {
    local path="$1"

    if [[ -e "$path" ]]; then
        rm -rf "$path" 2>/dev/null || true
    fi
}

# Create directory if it doesn't exist
# Usage: ensure_dir /path/to/dir
ensure_dir() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" 2>/dev/null || {
            log_error "Failed to create directory: $dir"
            return 1
        }
    fi
}

# Interactive yes/no prompt with gum (custom colors, no help text)
# Usage: if ask_yes_no "Continue?"; then ...
#        if ask_yes_no "Continue?" "y"; then ...  # default to yes
#        if confirm "Continue?"; then ...          # alias, default yes
#        if confirm_action "Continue?"; then ...   # alias, default yes
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"  # Default to 'no'

    # Auto-answer yes in non-interactive mode
    if [[ "${AUTO_YES:-false}" == "true" ]]; then
        return 0
    fi

    if command -v gum &>/dev/null; then
        # Use custom colors and hide help text
        local gum_opts=(
            --no-show-help
            --selected.foreground="2"        # Green for selected option
            --selected.bold=true
            --unselected.foreground="7"      # Light gray for unselected
        )

        if [[ "$default" == "y" ]] || [[ "$default" == "true" ]]; then
            gum confirm "${gum_opts[@]}" --default=true "$question"
        else
            gum confirm "${gum_opts[@]}" --default=false "$question"
        fi
    else
        # Fallback to simple prompt
        local prompt="$question"
        [[ "$default" == "y" ]] || [[ "$default" == "true" ]] && prompt="$prompt (Y/n)" || prompt="$prompt (y/N)"

        read -p "$prompt " -n 1 -r
        echo

        if [[ "$default" == "y" ]] || [[ "$default" == "true" ]]; then
            [[ $REPLY =~ ^[Nn]$ ]] && return 1 || return 0
        else
            [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
        fi
    fi
}

# Alias for ask_yes_no with default yes
confirm() {
    ask_yes_no "$1" "y"
}

# Alias for ask_yes_no (for backward compatibility)
confirm_action() {
    ask_yes_no "$1" "y"
}

# Get user input (consolidated from multiple files)
# Usage: name=$(get_input "Enter your name")
#        name=$(get_input "Enter your name" "default value")
#        name=$(get_input "Enter your name" "" "placeholder text")
get_input() {
    local prompt="$1"
    local default="$2"
    local placeholder="${3:-}"

    if command -v gum &>/dev/null; then
        local cmd=(gum input)
        [[ -n "$placeholder" ]] && cmd+=(--placeholder "$placeholder") || cmd+=(--prompt "$prompt ")
        [[ -n "$default" ]] && cmd+=(--value "$default")
        "${cmd[@]}"
    else
        if [[ -n "$default" ]]; then
            read -p "$prompt [$default]: " value
            echo "${value:-$default}"
        else
            read -p "$prompt: " value
            echo "$value"
        fi
    fi
}
