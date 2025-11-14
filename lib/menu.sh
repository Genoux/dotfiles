#!/bin/bash
# Reusable menu patterns for dotfiles management

# Generic submenu handler
# Usage: show_submenu "Title" callback_function
show_submenu() {
    local title="$1"
    local callback="$2"

    while true; do
        clear_screen "$title"

        # Call the callback function which should return menu actions
        local -a actions
        "$callback" actions

        # Check if we should return (empty actions array)
        if [[ ${#actions[@]} -eq 0 ]]; then
            return
        fi

        # Show menu
        local action=$(choose_option "${actions[@]}")

        # ESC pressed - go back
        [[ -z "$action" ]] && return

        # Handle "Back" option
        [[ "$action" == "Back" ]] && return

        # Execute the action (callback handles it)
        "${callback}_execute" "$action"
    done
}

# Run operation with automatic status display and pause
# Usage: run_operation "message" command_function [args...]
run_operation() {
    local message="$1"
    shift
    local command="$1"
    shift

    clear_screen
    if [[ -n "$message" ]]; then
        log_info "$message"
        echo
    fi

    # Execute the command
    "$command" "$@"
    local exit_code=$?

    echo
    read -p "Press Enter to continue..."

    return $exit_code
}

# Show status summary with consistent formatting
# Usage: show_status_summary title count_label count_value [more_labels_and_values...]
show_status_summary() {
    local title="$1"
    shift

    while [[ $# -ge 2 ]]; do
        show_info "$1" "$2"
        shift 2
    done
    echo
}

# Interactive confirmation with gum
# Usage: if confirm_action "Are you sure?"; then ...
confirm_action() {
    local message="${1:-Are you sure?}"

    if command -v gum &>/dev/null; then
        gum confirm "$message"
    else
        read -p "$message (y/N) " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# Multi-select menu with gum or fallback
# Usage: selected=$(multi_select "Header" "option1" "option2" "option3")
multi_select() {
    local header="$1"
    shift
    local options=("$@")

    if command -v gum &>/dev/null; then
        printf '%s\n' "${options[@]}" | gum choose --no-limit --header "$header"
    else
        # Fallback: show numbered list and accept comma-separated input
        log_info "$header"
        local i=1
        for opt in "${options[@]}"; do
            echo "$i) $opt"
            ((i++))
        done
        echo
        read -p "Enter numbers separated by commas: " selection

        # Parse selection
        IFS=',' read -ra nums <<< "$selection"
        for num in "${nums[@]}"; do
            num=$(echo "$num" | xargs) # trim whitespace
            if [[ $num =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#options[@]} ]]; then
                echo "${options[$((num-1))]}"
            fi
        done
    fi
}

# Show operation spinner
# Usage: with_spinner "Installing..." command args...
with_spinner() {
    local message="$1"
    shift

    if command -v gum &>/dev/null; then
        gum spin --spinner dot --title "$message" -- "$@"
    else
        log_info "$message"
        "$@"
    fi
}

# Generic two-action menu (e.g., Apply/Show Details/Back)
# Usage: simple_menu "Title" status_func apply_func details_func
simple_menu() {
    local title="$1"
    local status_func="$2"
    local apply_func="$3"
    local details_func="$4"

    while true; do
        clear_screen "$title"

        # Show quick status
        "$status_func"
        echo

        local action=$(choose_option \
            "Apply" \
            "Show details" \
            "Back")

        [[ -z "$action" ]] && return

        case "$action" in
            "Apply")
                run_operation "" "$apply_func"
                ;;
            "Show details")
                run_operation "" "$details_func"
                ;;
            "Back")
                return
                ;;
        esac
    done
}
