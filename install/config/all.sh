#!/bin/bash
# Run all config setup steps

run_logged "$DOTFILES_INSTALL/config/network.sh"
run_logged "$DOTFILES_INSTALL/config/stow.sh"
run_logged "$DOTFILES_INSTALL/config/shell.sh"
run_logged "$DOTFILES_INSTALL/config/theme.sh"
run_logged "$DOTFILES_INSTALL/config/ags.sh"
run_logged "$DOTFILES_INSTALL/config/hyprland.sh"

