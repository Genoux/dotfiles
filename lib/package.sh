#!/bin/bash
# Package management - Main entry point
# This file sources all package management modules

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
fi

# Package file locations
PACKAGES_FILE="$DOTFILES_DIR/packages/arch.package"
AUR_PACKAGES_FILE="$DOTFILES_DIR/packages/aur.package"

# Source all package management modules
source "$DOTFILES_DIR/lib/package/core.sh"      # yay, Node.js, system prep
source "$DOTFILES_DIR/lib/package/install-official.sh" # Official package installation
source "$DOTFILES_DIR/lib/package/install-aur.sh"      # AUR package installation
source "$DOTFILES_DIR/lib/package/install.sh"          # Package installation orchestration
source "$DOTFILES_DIR/lib/package/custom.sh"    # Custom (GitHub PKGBUILD) package builds
source "$DOTFILES_DIR/lib/package/verify.sh"           # Installation verification
source "$DOTFILES_DIR/lib/package/update.sh"    # System updates
source "$DOTFILES_DIR/lib/package/status.sh"    # Status display
source "$DOTFILES_DIR/lib/hardware-packages.sh" # Hardware package management

# Public API:
# - packages_install()        Install all packages from dotfiles (official + AUR)
# - packages_custom()         Build custom GitHub PKGBUILD packages
# - packages_update()         Update system packages
# - packages_status()         Show package status
# - packages_prepare()        Prepare system (internal, but callable)
# - ensure_yay_installed()    Ensure yay is installed (internal, but callable)
# - packages_menu()           Interactive menu for package management

# Package management menu
packages_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"

    while true; do
        clear_screen "Packages"

        # Show current package count
        local pkg_count=$(grep -cvE '^#|^$' "$DOTFILES_DIR/packages/arch.package" 2>/dev/null || echo 0)
        local aur_count=$(grep -cvE '^#|^$' "$DOTFILES_DIR/packages/aur.package" 2>/dev/null || echo 0)
        show_quick_summary "Tracked" "$pkg_count official + $aur_count AUR"

        local action=$(choose_option \
            "Install packages" \
            "Build custom packages" \
            "Update system" \
            "Show details" \
            "Back")

        [[ -z "$action" ]] && return  # ESC pressed

        case "$action" in
            "Install packages")
                run_operation "" packages_install
                ;;
            "Build custom packages")
                run_operation "" packages_custom
                ;;
            "Update system")
                clear_screen
                packages_update
                local update_exit=$?
                if [[ $update_exit -ne 0 ]]; then
                    echo
                    if [[ -n "${DOTFILES_LOG_FILE:-}" && -f "$DOTFILES_LOG_FILE" ]]; then
                        tail -n 120 "$DOTFILES_LOG_FILE" | gum pager
                    fi
                fi
                pause
                ;;
            "Show details")
                run_operation "" packages_status
                ;;
            "Back")
                return
                ;;
        esac
    done
}
