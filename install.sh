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

for arg in "$@"; do
    case "$arg" in
        --skip-packages) SKIP_PACKAGES=true ;;
        --skip-configs) SKIP_CONFIGS=true ;;
        --help)
            echo "Dotfiles Installation Script"
            echo ""
            echo "Usage: ./install.sh [options]"
            echo ""
            echo "Options:"
            echo "  --skip-packages  Skip package installation"
            echo "  --skip-configs   Skip configuration linking"
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

# Initialize logging
init_logging "install"

# Setup error handling
setup_error_handling

# Welcome message
clear_screen
if command -v gum &>/dev/null; then
    gum style \
        --border double \
        --border-foreground 212 \
        --padding "1 2" \
        --margin "1 0" \
        "$(gum style --bold --foreground 212 'Dotfiles Installation')" \
        "" \
        "This will set up your system with:" \
        "  • Packages from packages.txt & aur-packages.txt" \
        "  • Configurations via GNU Stow" \
        "  • Shell setup (zsh + Oh My Zsh)" \
        "  • Theme configuration" \
        "  • Hyprland monitors" \
        "" \
        "$(gum style --foreground 240 'This is designed for fresh installations.')" \
        "$(gum style --foreground 240 'For daily management, use: dotfiles <command>')"
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Dotfiles Installation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "This will set up your system with:"
    echo "  • Packages from packages.txt & aur-packages.txt"
    echo "  • Configurations via GNU Stow"
    echo "  • Shell setup (zsh + Oh My Zsh)"
    echo "  • Theme configuration"
    echo "  • Hyprland monitors"
    echo ""
    echo "This is designed for fresh installations."
    echo "For daily management, use: dotfiles <command>"
    echo ""
fi

# Confirm to proceed
if ! confirm "Proceed with installation?"; then
    log_info "Installation cancelled"
    exit 0
fi

echo

# Show hardware info
show_hardware_info

# Check prerequisites
log_section "Checking Prerequisites"
check_prerequisites
echo

# Run installation phases
log_section "Starting Installation"
log_info "Installation started at $(date)"
log_info "Logs: $DOTFILES_LOG_FILE"
echo

# Phase 1: Packages
if ! $SKIP_PACKAGES; then
    log_section "Phase 1: Packages"
    source "$DOTFILES_INSTALL/packages/all.sh"
    echo
else
    log_info "Skipping package installation"
    echo
fi

# Phase 2: Configuration
if ! $SKIP_CONFIGS; then
    log_section "Phase 2: Configuration"
    source "$DOTFILES_INSTALL/config/all.sh"
    echo
else
    log_info "Skipping configuration"
    echo
fi

# Phase 3: Post-installation
log_section "Phase 3: Finishing Up"
source "$DOTFILES_INSTALL/post/all.sh"

# Finish logging
finish_logging

# Exit successfully
exit 0

