#!/bin/bash

show_completion_screen() {
    clear
    echo
    # Green check, blue text for completion
    printf "\033[92m✓\033[0m \033[94mInstallation Complete\033[0m\n"
    echo
    # Blue text for results
    printf "\033[94mInstalled:\033[0m\n"
    echo "  • Packages"
    echo "  • Configurations"
    echo "  • Theme"
    echo

    # Check if reboot is needed
    if [[ -f "$HOME/.local/state/dotfiles/.reboot_needed" ]]; then
        echo
        printf "\033[93m⚠\033[0m  \033[93mReboot required to apply all changes\033[0m\n"
    fi

    echo
    echo "Next steps:"
    echo "  • Reboot or log out and back in"
    echo "  • Start Hyprland: uwsm start hyprland-uwsm.desktop"
    echo
    echo "[L] View install log  [R] Reboot now  [Q] Quit"
    echo
}

view_install_log() {
    local log_file="${DOTFILES_INSTALL_LOG:-$HOME/.local/state/dotfiles/install.log}"

    if [[ ! -f "$log_file" ]]; then
        clear
        echo
        echo "Install log not found"
        echo
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi

    clear
    if command -v less &>/dev/null; then
        less "$log_file"
    else
        cat "$log_file"
        echo
        read -n 1 -s -r -p "Press any key to continue..."
    fi
}

while true; do
    show_completion_screen

    read -n 1 -s -r key
    case "${key,,}" in
        l)
            view_install_log
            ;;
        r)
            clear
            echo
            printf "\033[94mRebooting system...\033[0m\n"
            echo
            rm -f "$HOME/.local/state/dotfiles/.reboot_needed"
            sudo systemctl reboot
            ;;
        q|$'\n'|$'\x0a')
            clear
            break
            ;;
    esac
done