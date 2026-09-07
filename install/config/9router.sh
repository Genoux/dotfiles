#!/bin/bash
# Provision the local 9router AI gateway (Docker image + machine-local client env).

set -euo pipefail

if [[ -z "${DOTFILES_DIR:-}" ]]; then
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
export DOTFILES_DIR
export DOTFILES_INSTALL="${DOTFILES_INSTALL:-$DOTFILES_DIR/install}"

if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
fi

NINEROUTER_IMAGE="decolua/9router:latest"
NINEROUTER_ENV="$HOME/.config/9router/env"

ninerouter_setup() {
    if ! command -v docker &>/dev/null; then
        log_warning "docker not installed; skipping 9router gateway setup"
        return 0
    fi

    if ! docker info &>/dev/null; then
        log_warning "docker daemon unreachable; run 'sudo systemctl enable --now docker' then re-run this script"
        return 0
    fi

    log_info "Pulling $NINEROUTER_IMAGE..."
    docker pull "$NINEROUTER_IMAGE"

    # The gateway mounts this from the host; create it before first start so the
    # container does not have it created root-owned by the docker daemon.
    mkdir -p "$HOME/.9router"

    if [[ ! -f "$NINEROUTER_ENV" ]]; then
        log_info "No client env at $NINEROUTER_ENV; CLIs will keep using their upstream providers"
        log_info "Copy env.example to env and paste the dashboard key to route them through 9router"
    fi

    log_success "9router gateway ready — dashboard at http://localhost:20128"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ninerouter_setup "$@"
fi
