#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$DOTFILES_DIR/install/helpers/all.sh"

log_section "Managing Systemd Services"
if ! systemctl --user daemon-reload; then
    log_warning "User systemd is unavailable. Log in normally and run dotfiles config link."
    exit 1
fi

for retired_unit in swaync.service mako.service dunst.service; do
    if [[ "$(systemctl --user show -p LoadState --value "$retired_unit")" == "loaded" ]]; then
        systemctl --user disable --now "$retired_unit"
        log_info "$retired_unit disabled so Quickshell can own notifications"
    fi
done

shopt -s nullglob
for unit_file in "$DOTFILES_DIR"/stow/*/.config/systemd/user/*.service "$DOTFILES_DIR"/stow/*/.config/systemd/user/*.timer; do
    unit="$(basename "$unit_file")"
    if ! grep -q '^\[Install\]' "$unit_file"; then
        continue
    fi
    systemctl --user enable "$unit"
    if grep -q 'graphical-session.target' "$unit_file" && ! systemctl --user is-active --quiet graphical-session.target; then
        log_info "$unit enabled for the next graphical session"
        continue
    fi
    if [[ "$(systemctl --user show -p Type --value "$unit")" == "oneshot" ]]; then
        continue
    fi
    if ! systemctl --user is-active --quiet "$unit"; then
        systemctl --user start "$unit"
    else
        started=$(systemctl --user show -p ActiveEnterTimestamp --value "$unit")
        started_epoch=$(date -d "$started" +%s 2>/dev/null || echo 0)
        unit_mtime=$(stat -Lc %Y "$unit_file")
        if (( started_epoch > 0 && unit_mtime > started_epoch )); then
            systemctl --user restart "$unit"
        fi
    fi
    log_success "$unit ready"
done
