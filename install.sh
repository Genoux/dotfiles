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
        "  • Mirror updates & database sync" \
        "  • Smart package reconciliation" \
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
    echo "  • Mirror updates & database sync"
    echo "  • Smart package reconciliation"
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

# Show installation phases
if command -v gum &>/dev/null; then
    gum style --foreground 14 "Installation will proceed through 3 phases:"
    echo "  1. Package Installation"
    echo "  2. Configuration Linking"
    echo "  3. Final Setup"
    echo
fi

# Phase 1: Packages
if ! $SKIP_PACKAGES; then
    log_section "Phase 1/3: Package Installation"
    log_info "Installing system packages from packages.txt and aur-packages.txt"
    echo
    source "$DOTFILES_INSTALL/packages/all.sh"
    echo
    log_success "✓ Phase 1 complete"
    echo
else
    log_info "Skipping package installation (--skip-packages)"
    echo
fi

# Phase 2: Configuration
if ! $SKIP_CONFIGS; then
    log_section "Phase 2/3: Configuration Setup"
    log_info "Linking configurations, applying theme, and setting up environment"
    echo
    source "$DOTFILES_INSTALL/config/all.sh"
    echo
    log_success "✓ Phase 2 complete"
    echo
else
    log_info "Skipping configuration (--skip-configs)"
    echo
fi

# Phase 3: Post-installation
log_section "Phase 3/3: Final Setup"
log_info "Completing installation and verifying setup"
echo
source "$DOTFILES_INSTALL/post/all.sh"

# Finish logging
finish_logging

# Exit successfully
exit 0

