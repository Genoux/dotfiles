#!/bin/bash

[[ -n "${WORKSPACE_MANAGER_REPO:-}" ]] || return 0
export DOTFILES_DIR="$WORKSPACE_MANAGER_REPO"
export DOTFILES_INSTALL="$DOTFILES_DIR/install"

# install-state declares its phase array at source scope; keep it at shell scope.
builtin source "$DOTFILES_DIR/lib/install-state.sh"

manager_bind_ui() {
    init_logging() { export DOTFILES_LOG_FILE="$WORKSPACE_MANAGER_LOG"; }
    start_log_monitor() { :; }
    stop_log_monitor() { :; }
    finish_logging() { :; }
    pause() { :; }
    clear() { :; }
    clear_screen() { [[ -z "${1:-}" ]] || printf '\n%s\n' "$1"; return 0; }
    show_completion_menu() { printf '%s\n' "${1:-Operation complete}"; }
    ask_yes_no() { gum confirm --default=false "$1"; }
    log_info() { printf '%s\n' "$*"; }
    log_success() { printf '%s\n' "$*"; }
    log_warning() { printf 'Warning: %s\n' "$*"; }
    log_error() { printf 'Error: %s\n' "$*"; touch "$WORKSPACE_MANAGER_FAILURE"; }
    run_command_logged() {
        local description="$1"
        shift
        printf '\n%s\n' "$description"
        "$@"
    }
    run_logged() {
        printf '\n%s\n' "$1"
        command bash "$@"
    }
    export -f init_logging start_log_monitor stop_log_monitor finish_logging pause clear clear_screen
    export -f show_completion_menu ask_yes_no log_info log_success log_warning log_error run_command_logged run_logged
    export DOTFILES_LOG_FILE="$WORKSPACE_MANAGER_LOG"
}

source() {
    case "$1" in
        "$DOTFILES_DIR/lib/menu.sh"|"$DOTFILES_DIR/lib/install-state.sh") return 0 ;;
        "$DOTFILES_DIR/install/post/all.sh") show_completion_menu "Installation complete"; return 0 ;;
    esac
    builtin source "$@"
    local source_result=$?
    manager_bind_ui
    return "$source_result"
}

gum() { python3 "$WORKSPACE_MANAGER_BRIDGE" gum "$@"; }
sudo() { python3 "$WORKSPACE_MANAGER_BRIDGE" sudo "$@"; }
yay() { command yay --sudo pkexec --sudoflags '' --sudoloop=false "$@"; }
read() {
    if [[ "$*" == *'Press any key'* || "$*" == *'Press Enter'* ]]; then
        return 0
    fi
    builtin read "$@"
}
export -f source gum sudo yay read manager_bind_ui
manager_bind_ui
