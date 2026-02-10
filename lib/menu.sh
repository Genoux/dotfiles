#!/bin/bash
# Reusable menu patterns for dotfiles management
# Requires: gum (charmbracelet/gum)

# Show post-operation completion prompt with log/reboot/continue options
# Usage: show_completion_menu "Operation complete message"
show_completion_menu() {
    local message="${1:-Operation complete}"

    tput civis 2>/dev/null
    while true; do
        clear
        echo
        printf "\033[92m✓\033[0m \033[94m%s\033[0m\n" "$message"
        echo
        echo "[R] Reboot now  [Q] Continue"
        echo

        read -n 1 -s -r key
        case "${key,,}" in
            r)
                clear
                echo
                printf "\033[94mRebooting system...\033[0m\n"
                echo
                rm -f "$HOME/.local/state/dotfiles/.reboot_needed"
                sudo systemctl reboot
                ;;
            q|$'\n'|$'\x0a')
                tput cnorm 2>/dev/null
                clear
                break
                ;;
        esac
    done
}

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

        clear

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

    # Pause before returning to menu
    pause

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

# Show quick summary at top of menus (standardized format)
# Usage: show_quick_summary "Label1" "Value1" "Label2" "Value2" ...
# Displays 2-4 key metrics in consistent format
show_quick_summary() {
    while [[ $# -ge 2 ]]; do
        show_info "$1" "$2"
        shift 2
    done
    echo
}

# Interactive confirmation is now in lib/common.sh
# confirm_action() is available from lib/common.sh

# Multi-select menu with gum
# Usage: selected=$(multi_select "Header" "option1" "option2" "option3")
multi_select() {
    local header="$1"
    shift
    local options=("$@")
    printf '%s\n' "${options[@]}" | gum choose --no-limit --header "$header" --no-show-help
}

# Show operation spinner
# Usage: with_spinner "Installing..." command args...
with_spinner() {
    local message="$1"
    shift
    gum spin --spinner dot --title "$message" -- "$@"
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

        clear

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
