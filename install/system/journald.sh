#!/bin/bash
# systemd journald configuration
# Caps journal size so log growth cannot fill the root partition

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
else
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "systemd Journald"

if [[ -d "$SYSTEM_DIR/systemd/journald.conf.d" ]]; then
    sudo mkdir -p /etc/systemd/journald.conf.d
    for file in "$SYSTEM_DIR/systemd/journald.conf.d"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            sudo cp "$file" /etc/systemd/journald.conf.d/
            log_success "$filename"
        fi
    done

    # Safe to restart: journald re-execs without dropping the session.
    sudo systemctl restart systemd-journald 2>/dev/null || true
    log_info "Journal usage: $(journalctl --disk-usage 2>/dev/null | sed 's/^.*take up //')"
fi
