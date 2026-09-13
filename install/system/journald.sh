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
    journald_changed=false
    for file in "$SYSTEM_DIR/systemd/journald.conf.d"/*; do
        [[ -f "$file" ]] || continue
        filename=$(basename "$file")
        if install_file_if_changed "$file" "/etc/systemd/journald.conf.d/$filename"; then
            journald_changed=true
            log_success "$filename"
        else
            log_info "$filename already up to date"
        fi
    done

    # Safe to restart: journald re-execs without dropping the session. Only
    # do it when the config actually changed.
    if $journald_changed; then
        sudo systemctl restart systemd-journald 2>/dev/null || true
    fi
    log_info "Journal usage: $(journalctl --disk-usage 2>/dev/null | sed 's/^.*take up //')"
fi
