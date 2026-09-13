#!/bin/bash

show_completion_screen() {
    [[ -t 1 ]] && clear
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
        printf "\033[93m⚠\033[0m  \033[93mReboot required to apply all changes\033[0m\n"
    fi

    echo
    echo "Next steps:"
    echo "  • Reboot or log out and back in"
    echo "  • Start Hyprland: uwsm start hyprland-uwsm.desktop"
    echo
    local log_file="${DOTFILES_INSTALL_LOG:-$HOME/.local/state/dotfiles/install.log}"
    if [[ -f "$log_file" ]]; then
        awk '/\] \[WARN\]/ {sub(/^.*\] \[WARN\] /, ""); if (!seen[$0]++) print "  Warning: " $0}' "$log_file"
    fi
    if [[ -t 0 && -t 1 ]]; then
        echo "[L] View install log  [R] Reboot now  [Q] Quit"
        echo
    fi
}

view_install_log() {
    local log_file="${DOTFILES_INSTALL_LOG:-$HOME/.local/state/dotfiles/install.log}"

    if [[ ! -f "$log_file" ]]; then
        [[ -t 1 ]] && clear
        echo
        echo "Install log not found"
        echo
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi

    [[ -t 1 ]] && clear
    if command -v less &>/dev/null; then
        less "$log_file"
    else
        cat "$log_file"
        echo
        read -n 1 -s -r -p "Press any key to continue..."
    fi
}

if [[ ! -t 0 || ! -t 1 ]]; then
    show_completion_screen
    exit 0
fi

while true; do
    show_completion_screen

    read -n 1 -s -r key || break
    case "${key,,}" in
        l)
            view_install_log
            ;;
        r)
            [[ -t 1 ]] && clear
            echo
            printf "\033[94mRebooting system...\033[0m\n"
            echo
            rm -f "$HOME/.local/state/dotfiles/.reboot_needed"
            sudo systemctl reboot
            ;;
        q|$'\n'|$'\x0a')
            [[ -t 1 ]] && clear
            break
            ;;
    esac
done