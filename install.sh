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
RESUME=false
ROLLBACK_PHASE=""
SHOW_STATE=false
FORCE_FRESH=false
export AUTO_YES=true  # Full install defaults to yes
export FULL_INSTALL=true  # Mark this as full install

for arg in "$@"; do
    case "$arg" in
        --skip-packages) SKIP_PACKAGES=true ;;
        --skip-configs) SKIP_CONFIGS=true ;;
        --yes|-y) export AUTO_YES=true ;;
        --resume) RESUME=true ;;
        --rollback=*) ROLLBACK_PHASE="${arg#*=}" ;;
        --state) SHOW_STATE=true ;;
        --fresh) FORCE_FRESH=true ;;
        --help)
            echo "Dotfiles Installation Script"
            echo ""
            echo "Usage: ./install.sh [options]"
            echo ""
            echo "Options:"
            echo "  --skip-packages     Skip package installation"
            echo "  --skip-configs      Skip configuration linking"
            echo "  --yes, -y           Automatically answer yes to prompts"
            echo "  --resume            Resume from last failure point"
            echo "  --rollback=PHASE    Rollback to specific phase"
            echo "  --state             Show current installation state"
            echo "  --fresh             Force fresh install (clear state)"
            echo "  --help              Show this help"
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

# Load state management and atomic operations
source "$DOTFILES_DIR/lib/install-state.sh"
source "$DOTFILES_DIR/lib/atomic.sh"

# Handle state commands
if $SHOW_STATE; then
    show_state
    exit 0
fi

if [[ -n "$ROLLBACK_PHASE" ]]; then
    rollback_to_phase "$ROLLBACK_PHASE"
    exit $?
fi

# Initialize logging
init_logging "install"

# Setup error handling
setup_error_handling

# Initialize or resume state
if $FORCE_FRESH; then
    clear_state
    init_state
    atomic_begin
elif $RESUME && can_resume; then
    log_info "Resuming installation from last failure point..."
    RESUME_POINT=$(get_resume_point)
    log_info "Resume point: $RESUME_POINT"

    if ! atomic_in_progress; then
        atomic_begin
    fi
else
    init_state
    atomic_begin
fi

# Setup atomic rollback on error (log the failing command/line first, then roll back)
trap 'handle_error ${LINENO} "$BASH_COMMAND"; atomic_rollback; exit 1' ERR

# Check prerequisites
check_prerequisites

# Pre-flight phase
if ! is_phase_completed "preflight"; then
    start_phase "preflight"
    create_snapshot "preflight"

    source "$DOTFILES_DIR/lib/package/preflight.sh"
    if ! run_preflight_checks; then
        fail_phase "preflight" "Pre-flight checks failed"
        log_error "Run with --state to see details, --resume to retry"
        exit 1
    fi

    complete_phase "preflight"
    echo
fi

# Start live log monitor
start_log_monitor

# Hardware detection phase
if ! is_phase_completed "hardware_detect"; then
    start_phase "hardware_detect"
    create_snapshot "hardware_detect"

    source "$DOTFILES_DIR/lib/hardware-packages.sh"
    if ! hardware_packages_setup; then
        fail_phase "hardware_detect" "Hardware detection failed"
        exit 1
    fi

    complete_phase "hardware_detect"
    echo
fi

# Package installation phases
if ! $SKIP_PACKAGES; then
    # Official packages
    if ! is_phase_completed "packages_official"; then
        start_phase "packages_official"
        create_snapshot "packages_official"

        if ! source "$DOTFILES_INSTALL/packages/all.sh"; then
            fail_phase "packages_official" "Package installation failed"
            exit 1
        fi

        complete_phase "packages_official"
        echo
    fi
fi

# Config phases
if ! $SKIP_CONFIGS; then
    sudo -v

    if ! is_phase_completed "config_link"; then
        start_phase "config_link"
        create_snapshot "config_link"

        if ! source "$DOTFILES_INSTALL/config/all.sh"; then
            fail_phase "config_link" "Config linking failed"
            exit 1
        fi

        complete_phase "config_link"
        echo
    fi
fi

# Stop live log monitor
stop_log_monitor

# Verification phase
if ! is_phase_completed "verification"; then
    start_phase "verification"

    source "$DOTFILES_DIR/lib/package/verify.sh"
    if ! run_full_verification; then
        fail_phase "verification" "Verification failed"
        log_warning "Installation completed with warnings"
    else
        complete_phase "verification"
    fi
    echo
fi

# Mark as complete
mark_complete

# Commit atomic transaction
atomic_commit

# Cleanup old backups
atomic_cleanup 3

# Show finish screen
source "$DOTFILES_INSTALL/post/all.sh"

# Finish logging
finish_logging

# Stop sudo keep-alive
kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true

# Exit successfully
exit 0

