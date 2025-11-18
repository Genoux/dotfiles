#!/bin/bash
# Package management - Main entry point
# This file sources all package management modules

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Package file locations
PACKAGES_FILE="$DOTFILES_DIR/packages/arch.package"
AUR_PACKAGES_FILE="$DOTFILES_DIR/packages/aur.package"

# Source all package management modules
source "$DOTFILES_DIR/lib/package/core.sh"      # yay, Node.js, system prep
source "$DOTFILES_DIR/lib/package/install.sh"   # Package installation
source "$DOTFILES_DIR/lib/package/manage.sh"    # Interactive management
source "$DOTFILES_DIR/lib/package/update.sh"    # System updates
source "$DOTFILES_DIR/lib/package/sync.sh"      # Package list sync (deprecated)
source "$DOTFILES_DIR/lib/package/status.sh"    # Status display

# Public API:
# - packages_install()        Install all packages from dotfiles
# - packages_manage()         Interactive package management (recommended)
# - packages_update()         Update system packages
# - packages_status()         Show package status
# - packages_sync()           Sync package lists (deprecated - use manage)
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
        show_info "Tracked" "$pkg_count official + $aur_count AUR"
        echo
        
        local action=$(choose_option \
            "Manage packages" \
            "Update system" \
            "Show status" \
            "Back")

        [[ -z "$action" ]] && return  # ESC pressed

        case "$action" in
            "Manage packages")
                run_operation "" packages_manage
                ;;
            "Update system")
                run_operation "" packages_update || {
                    echo
                    log_error "Update failed. Showing recent log output:"
                    echo
                    if [[ -n "${DOTFILES_LOG_FILE:-}" && -f "$DOTFILES_LOG_FILE" ]]; then
                        # Use gum pager for better log viewing
                        tail -n 120 "$DOTFILES_LOG_FILE" | gum pager
                    else
                        echo "No log file available. Rerun: dotfiles packages update 2>&1 | tee /tmp/dotfiles-update.log"
                        pause
                    fi
                }
                ;;
            "Show status")
                run_operation "" packages_status
                ;;
            "Back")
                return
                ;;
        esac
    done
}
