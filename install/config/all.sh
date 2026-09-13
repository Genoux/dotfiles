#!/bin/bash
# Run all config setup steps

run_logged "$DOTFILES_INSTALL/config/stow.sh" || return 1
run_logged "$DOTFILES_INSTALL/system/setup.sh" || return 1
run_logged "$DOTFILES_INSTALL/config/shell.sh" || return 1
run_logged "$DOTFILES_INSTALL/config/theme.sh" || return 1
run_logged "$DOTFILES_INSTALL/config/hyprland.sh" || return 1
# gentle-ai is an optional dev tool (its go install can fail offline / on go issues);
# never let it fail the whole config phase after stow/theme/monitors succeeded.
run_logged "$DOTFILES_INSTALL/config/gentle-ai.sh" || log_warning "gentle-ai setup skipped (optional) — run install/config/gentle-ai.sh later"

