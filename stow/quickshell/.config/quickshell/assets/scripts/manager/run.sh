#!/bin/bash
set -o pipefail
export WORKSPACE_MANAGER_PGID="$BASHPID"
source "$DOTFILES_DIR/install/helpers/all.sh"
export DOTFILES_HELPERS_LOADED=true
source "$DOTFILES_DIR/lib/package.sh"
source "$DOTFILES_DIR/lib/config.sh"
source "$DOTFILES_DIR/lib/shell.sh"
source "$DOTFILES_DIR/lib/theme.sh"
source "$DOTFILES_DIR/lib/hyprland.sh"
source "$DOTFILES_DIR/lib/system.sh"
builtin source "$DOTFILES_DIR/lib/menu.sh"
manager_bind_ui

operation="$1"
shift
case "$operation" in
    system_status)
        show_hardware_info
        packages_status
        config_status
        theme_status
        shell_status
        hyprland_status
        ;;
    verify) run_full_verification ;;
    packages_manage) packages_manage ;;
    packages_install) packages_install ;;
    packages_unlisted) packages_clean_unlisted ;;
    packages_status) packages_status ;;
    configs_manage) config_manage_interactive ;;
    configs_link) config_link_all ;;
    configs_unlink) config_unlink_all ;;
    configs_status) config_status ;;
    hardware_setup) hardware_packages_setup ;;
    hardware_status) hardware_packages_status ;;
    system_apply) system_apply ;;
    system_details) system_status ;;
    theme_install) theme_install_gtk ;;
    theme_remove) theme_uninstall_gtk ;;
    theme_status) theme_status ;;
    shell_setup) shell_setup ;;
    shell_status) shell_status ;;
    hyprland_setup) hyprland_setup_all ;;
    hyprland_status) hyprland_status ;;
    full_install) exec bash "$DOTFILES_DIR/install.sh" "$@" ;;
    resume_install) exec bash "$DOTFILES_DIR/install.sh" --resume "$@" ;;
    install_state) show_state ;;
    *) printf 'Unknown operation: %s\n' "$operation" >&2; exit 2 ;;
esac
