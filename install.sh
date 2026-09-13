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
        --resume) ;;
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
            echo "  --resume            Resume an interrupted install (the default)"
            echo "  --rollback=PHASE    Rollback to specific phase"
            echo "  --state             Show current installation state"
            echo "  --fresh             Force fresh install (clear state)"
            echo "  --help              Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $arg. Run ./install.sh --help." >&2; exit 2 ;;
    esac
done

source "$DOTFILES_INSTALL/helpers/all.sh"
source "$DOTFILES_DIR/lib/install-state.sh"
source "$DOTFILES_DIR/lib/atomic.sh"
source "$DOTFILES_DIR/lib/package.sh"

if $SHOW_STATE; then
    require_command jq || exit 1
    show_state
    exit 0
fi

if [[ -n "$ROLLBACK_PHASE" ]]; then
    require_command jq || exit 1
    rollback_to_phase "$ROLLBACK_PHASE"
    exit $?
fi

mkdir -p "$DOTFILES_LOG_DIR"
exec 9>"$DOTFILES_LOG_DIR/install.lock"
if ! flock -n 9; then
    log_error "Another dotfiles installation is running. Wait for it to finish."
    exit 1
fi

init_logging "install"
trap cleanup_install EXIT
trap handle_install_interrupt INT TERM
trap 'handle_error ${LINENO} "$BASH_COMMAND"; exit 1' ERR

if [[ $EUID -eq 0 || -d /run/archiso ]]; then
    log_error "Run this after installing Arch and rebooting, as your normal user (not root or the live ISO)."
    exit 1
fi
if [[ "$(uname -m)" != "x86_64" ]]; then
    log_error "These package manifests support x86_64 Arch Linux. $(uname -m) is not supported."
    exit 1
fi
for prerequisite in pacman sudo; do
    require_command "$prerequisite" || exit 1
done
export PATH="$HOME/.local/bin:$PATH"
export LC_ALL=C.UTF-8

log_info "Installing on $(hostname): $(uname -m), $(nproc) CPUs"
log_info "Full log: $DOTFILES_LOG_FILE"
if ! ensure_sudo; then
    log_error "Sudo authentication failed. Your user needs sudo access."
    exit 1
fi
while kill -0 "$$" 2>/dev/null; do
    sudo -n true || break
    sleep 50
done &
SUDO_KEEPALIVE_PID=$!

MISSING_DEPS=()
for dep in stow gum jq pciutils curl git; do
    check_cmd="$dep"
    [[ "$dep" == "pciutils" ]] && check_cmd="lspci"
    command -v "$check_cmd" &>/dev/null || MISSING_DEPS+=("$dep")
done
if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    run_command_logged "Install bootstrap dependencies" sudo pacman -Syu --needed --noconfirm "${MISSING_DEPS[@]}" || exit 1
fi

# Initialize or resume state
if $FORCE_FRESH; then
    clear_state
    init_state
    atomic_begin
elif can_resume; then
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

DOTFILES_INSTALL_STATE_READY=true

# Hardware detection phase — detects GPU/CPU only (no network or pacman/yay
# calls) and selects which static packages/hardware/*.package manifests
# apply to this machine. Runs before preflight specifically so preflight's
# package-name validation checks exactly what was just selected.
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

# Pre-flight phase
if ! $SKIP_PACKAGES; then
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

# Package installation phases
if ! $SKIP_PACKAGES; then
    # Official packages
    if ! is_phase_completed "packages_official"; then
        start_phase "packages_official"
        create_snapshot "packages_official"

        if ! run_logged "$DOTFILES_INSTALL/packages/base.sh" official; then
            fail_phase "packages_official" "Package installation failed"
            exit 1
        fi

        complete_phase "packages_official"
        echo
    fi

    if ! is_phase_completed "packages_aur"; then
        start_phase "packages_aur"
        create_snapshot "packages_aur"
        if ! run_logged "$DOTFILES_INSTALL/packages/base.sh" aur; then
            fail_phase "packages_aur" "AUR package installation failed"
            exit 1
        fi
        complete_phase "packages_aur"
        echo
    fi
fi

# Config phases
if ! $SKIP_CONFIGS; then
    ensure_sudo

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

# Custom package builds (GitHub PKGBUILD repos) — last, since they may need
# tools/configs from the phases above.
if ! $SKIP_PACKAGES; then
    if ! is_phase_completed "packages_custom"; then
        start_phase "packages_custom"
        create_snapshot "packages_custom"

        if ! packages_custom; then
            fail_phase "packages_custom" "Custom package builds failed"
            exit 1
        fi

        complete_phase "packages_custom"
        echo
    fi
fi

# Stop live log monitor
stop_log_monitor

# Verification phase
start_phase "verification"

source "$DOTFILES_DIR/lib/package/verify.sh"
if ! run_full_verification; then
    fail_phase "verification" "Verification failed"
    exit 1
else
    complete_phase "verification"
fi
echo

# Mark as complete
mark_complete

# Commit atomic transaction
atomic_commit

# Cleanup old backups
atomic_cleanup 3

# Show finish screen
source "$DOTFILES_INSTALL/post/all.sh"


# Exit successfully
exit 0

