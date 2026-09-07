#!/bin/bash
# Run all config setup steps

run_logged "$DOTFILES_INSTALL/config/stow.sh"
run_logged "$DOTFILES_INSTALL/system/setup.sh"
run_logged "$DOTFILES_INSTALL/config/shell.sh"
run_logged "$DOTFILES_INSTALL/config/theme.sh"
run_logged "$DOTFILES_INSTALL/config/hyprland.sh"
# 9router needs a reachable docker daemon; a missing gateway must not fail the
# config phase, the CLIs just fall back to their upstream providers.
run_logged "$DOTFILES_INSTALL/config/9router.sh" || log_warning "9router setup skipped (optional) — run install/config/9router.sh later"
# gentle-ai is an optional dev tool (its go install can fail offline / on go issues);
# never let it fail the whole config phase after stow/theme/monitors succeeded.
run_logged "$DOTFILES_INSTALL/config/gentle-ai.sh" || log_warning "gentle-ai setup skipped (optional) — run install/config/gentle-ai.sh later"

