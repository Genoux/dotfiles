#!/bin/bash
# Dotfiles Installation Script
# For fresh system setup - runs all installation phases

set -eEo pipefail

# Define dotfiles locations
export DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_INSTALL="$DOTFILES_DIR/install"

# Parse arguments
SKIP_PACKAGES=false
SKIP_CONFIGS=false
export AUTO_YES=true  # Full install defaults to yes
export FULL_INSTALL=true  # Mark this as full install

for arg in "$@"; do
    case "$arg" in
        --skip-packages) SKIP_PACKAGES=true ;;
        --skip-configs) SKIP_CONFIGS=true ;;
        --yes|-y) export AUTO_YES=true ;;
        --help)
            echo "Dotfiles Installation Script"
            echo ""
            echo "Usage: ./install.sh [options]"
            echo ""
            echo "Options:"
            echo "  --skip-packages  Skip package installation"
            echo "  --skip-configs   Skip configuration linking"
            echo "  --yes, -y        Automatically answer yes to prompts"
            echo "  --help           Show this help"
            exit 0
            ;;
    esac
done

# Validate sudo access first
if ! sudo -v; then
    echo "Failed to authenticate"
    exit 1
fi

# Start sudo keep-alive in background
while true; do
    sudo -n true
    sleep 50
    kill -0 "$$" 2>/dev/null || exit
done &
SUDO_KEEPALIVE_PID=$!

# Ensure keep-alive is killed on exit
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# Check and install bootstrap dependencies (git assumed to be installed already)
echo "Checking bootstrap dependencies..."
MISSING_DEPS=()
for dep in stow gum jq; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo "Installing missing dependencies: ${MISSING_DEPS[*]}"
    sudo pacman -S --needed --noconfirm "${MISSING_DEPS[@]}" || {
        echo "Failed to install bootstrap dependencies: ${MISSING_DEPS[*]}"
        exit 1
    }
else
    echo "All bootstrap dependencies already installed ✓"
fi

# Load helpers
source "$DOTFILES_INSTALL/helpers/all.sh"

# Initialize logging
init_logging "install"

# Setup error handling
setup_error_handling

# Check prerequisites
check_prerequisites

# Start live log monitor
start_log_monitor

# Run installation
if ! $SKIP_PACKAGES; then
    source "$DOTFILES_INSTALL/packages/all.sh"
fi

if ! $SKIP_CONFIGS; then
    sudo -v
    source "$DOTFILES_INSTALL/config/all.sh"
fi

# Stop live log monitor
stop_log_monitor

# Show finish screen
source "$DOTFILES_INSTALL/post/all.sh"

# Finish logging
finish_logging

# Stop sudo keep-alive
kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true

# Exit successfully
exit 0

