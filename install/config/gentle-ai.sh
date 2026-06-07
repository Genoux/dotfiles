#!/bin/bash
# Gentle AI integration for dotfiles (Cursor workspace + stow-aware Claude sync).

set -euo pipefail

if [[ -z "${DOTFILES_DIR:-}" ]]; then
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
export DOTFILES_DIR
export DOTFILES_INSTALL="${DOTFILES_INSTALL:-$DOTFILES_DIR/install}"

if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

GENTLE_AI_BIN="${GENTLE_AI_BIN:-$HOME/.local/bin/gentle-ai}"
GGA_BIN="${GGA_BIN:-$HOME/.local/bin/gga}"

ensure_gentle_ai() {
    if command -v gentle-ai &>/dev/null; then
        GENTLE_AI_BIN="$(command -v gentle-ai)"
        return 0
    fi

    if [[ ! -x "$GENTLE_AI_BIN" ]]; then
        if ! command -v go &>/dev/null; then
            log_warning "gentle-ai not found; install Go or run: curl -fsSL https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/scripts/install.sh | bash"
            return 1
        fi

        log_info "Installing gentle-ai via go install..."
        go install github.com/gentleman-programming/gentle-ai/cmd/gentle-ai@latest
        GENTLE_AI_BIN="$HOME/.local/bin/gentle-ai"
    fi

    command -v "$GENTLE_AI_BIN" &>/dev/null
}

# gentle-ai refuses to read/write symlinked config during sync rollback.
materialize_stowed_file() {
    local live_path="$1"
    local stow_path="$2"

    if [[ ! -f "$stow_path" ]]; then
        log_error "Stowed file not found: $stow_path"
        return 1
    fi

    if [[ -L "$live_path" ]]; then
        log_info "Materializing $(basename "$live_path") for gentle-ai..."
        cp -f "$stow_path" "${live_path}.tmp"
        rm "$live_path"
        mv "${live_path}.tmp" "$live_path"
    elif [[ ! -e "$live_path" ]]; then
        cp -f "$stow_path" "$live_path"
    fi
}

restow_file() {
    local live_path="$1"
    local stow_path="$2"
    local stow_package="$3"

    if [[ ! -f "$live_path" ]]; then
        log_error "Expected live file at $live_path"
        return 1
    fi

    log_info "Writing $(basename "$live_path") back to stow..."
    cp -f "$live_path" "$stow_path"
    rm -f "$live_path"

    source "$DOTFILES_DIR/lib/config.sh"
    config_link "$stow_package"
}

run_with_stowed_file() {
    local stow_package="$1"
    local stow_path="$2"
    local live_path="$3"
    shift 3

    materialize_stowed_file "$live_path" "$stow_path" || return 1

    if ! "$@"; then
        log_error "Command failed; live file kept at $live_path (not re-stowed)"
        return 1
    fi

    restow_file "$live_path" "$stow_path" "$stow_package"
}

ensure_cursor_gentle_ai_prereqs() {
    if [[ ! -f "$HOME/.cursor/settings.json" ]]; then
        echo '{}' >"$HOME/.cursor/settings.json"
    fi

    if [[ -d "$DOTFILES_DIR/.cursor/agents" ]]; then
        mkdir -p "$HOME/.cursor/agents"
        local agent
        for agent in "$DOTFILES_DIR"/.cursor/agents/*.md; do
            [[ -f "$agent" ]] || continue
            cp -f "$agent" "$HOME/.cursor/agents/$(basename "$agent")"
        done
    fi
}

setup_gga() {
    if [[ ! -x "$GGA_BIN" ]]; then
        log_info "Skipping GGA hooks (binary not found at $GGA_BIN)"
        return 0
    fi

    if [[ ! -f "$DOTFILES_DIR/.gga" ]]; then
        "$GGA_BIN" init
    fi

    (cd "$DOTFILES_DIR" && "$GGA_BIN" install)
}

gentle_ai_setup() {
    log_info "Setting up Gentle AI (workspace scope, Cursor)..."

    ensure_gentle_ai || return 1
    ensure_cursor_gentle_ai_prereqs

    if ! "$GENTLE_AI_BIN" install \
        --scope=workspace \
        --agent cursor \
        --preset full-gentleman; then
        log_warning "gentle-ai install reported issues; project files may still be usable"
    fi

    (cd "$DOTFILES_DIR" && "$GENTLE_AI_BIN" skill-registry refresh)
    setup_gga

    log_success "Gentle AI workspace setup complete"
    log_info "Run '/sdd-init' in Cursor when you want SDD project context initialized"
}

gentle_ai_sync_claude() {
    local stow_settings="$DOTFILES_DIR/stow/claude/.claude/settings.json"
    local live_settings="$HOME/.claude/settings.json"

    ensure_gentle_ai || return 1

    log_info "Syncing gentle-ai managed Claude Code config..."
    run_with_stowed_file claude "$stow_settings" "$live_settings" \
        "$GENTLE_AI_BIN" sync --agent claude-code "$@"

    log_success "Claude Code gentle-ai sync complete"
}

gentle_ai_usage() {
    cat <<EOF
Usage: gentle-ai.sh [command]

Commands:
  setup                 Cursor workspace install + skill registry + GGA (default)
  sync claude-code      Sync Claude Code via stowed settings.json
EOF
}

gentle_ai_main() {
    local command="${1:-setup}"
    shift || true

    case "$command" in
        setup)
            gentle_ai_setup "$@"
            ;;
        sync)
            local agent="${1:-}"
            shift || true
            case "$agent" in
                claude-code) gentle_ai_sync_claude "$@" ;;
                "")
                    log_error "sync requires an agent (e.g. claude-code)"
                    gentle_ai_usage
                    return 1
                    ;;
                *)
                    log_error "Unknown sync agent: $agent"
                    gentle_ai_usage
                    return 1
                    ;;
            esac
            ;;
        help|-h|--help)
            gentle_ai_usage
            ;;
        *)
            log_error "Unknown command: $command"
            gentle_ai_usage
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gentle_ai_main "$@"
fi
