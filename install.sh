#!/bin/bash
# Dotfiles Installation Script
# For fresh system setup - runs all installation phases

set -eEo pipefail

# Define dotfiles locations
export DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_INSTALL="$DOTFILES_DIR/install"

# Parse arguments
export AUTO_YES=false  # Prompt for confirmation by default
export FULL_INSTALL=true  # Mark this as full install (tells sub-scripts to skip their own logging setup)

for arg in "$@"; do
    case "$arg" in
        --yes|-y) export AUTO_YES=true ;;
        --help)
            echo "Dotfiles Installation Script"
            echo ""
            echo "Usage: ./install.sh [options]"
            echo ""
            echo "Performs a complete system installation:"
            echo "  • Installs/updates all packages"
            echo "  • Applies system configuration"
            echo "  • Links dotfiles"
            echo ""
            echo "Options:"
            echo "  --yes, -y        Skip confirmation prompts"
            echo "  --help           Show this help"
            exit 0
            ;;
    esac
done

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

# Setup sudoers first (enables passwordless sudo for rest of install)
echo "Setting up sudoers..."
bash "$DOTFILES_INSTALL/system/sudoers.sh"

# Initialize logging
init_logging "install"

# Setup error handling
setup_error_handling

# Check prerequisites
check_prerequisites

# Confirm before proceeding with full installation
if [[ "${AUTO_YES}" != "true" ]]; then
    echo
    gum style --bold --foreground "$CONFIRM_TITLE_COLOR" "⚠ Full System Installation"
    echo
    echo "This will:"
    echo "  • Install/update system packages"
    echo "  • Modify system configuration files"
    echo "  • Link dotfiles to your home directory"
    echo
    if ! gum_confirm "Proceed with full installation?"; then
        exit 0
    fi
    echo
fi

# Start live log monitor
start_log_monitor

# Run full installation
source "$DOTFILES_INSTALL/packages/all.sh"
source "$DOTFILES_INSTALL/config/all.sh"

# Stop live log monitor
stop_log_monitor

# Show finish screen
source "$DOTFILES_INSTALL/post/all.sh"

# Finish logging
finish_logging

# Exit successfully
exit 0

