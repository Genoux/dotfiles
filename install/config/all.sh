#!/bin/bash
# Run all config setup steps

run_logged "$DOTFILES_INSTALL/config/stow.sh"
run_logged "$DOTFILES_INSTALL/system/setup.sh"
run_logged "$DOTFILES_INSTALL/config/shell.sh"
run_logged "$DOTFILES_INSTALL/config/theme.sh"
run_logged "$DOTFILES_INSTALL/config/hyprland.sh"
# gentle-ai is an optional dev tool (its go install can fail offline / on go issues);
# never let it fail the whole config phase after stow/theme/monitors succeeded.
run_logged "$DOTFILES_INSTALL/config/gentle-ai.sh" || log_warning "gentle-ai setup skipped (optional) — run install/config/gentle-ai.sh later"

