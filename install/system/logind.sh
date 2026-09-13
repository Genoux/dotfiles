#!/bin/bash
# systemd logind configuration
# Installs logind configuration for proper lid switch behavior and power management

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
else
    # Ensure helpers are sourced even if flag is set (might be from different shell)
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "systemd Logind"

# systemd logind configuration
if [[ -d "$SYSTEM_DIR/systemd/logind.conf.d" ]]; then
    logind_changed=false
    for file in "$SYSTEM_DIR/systemd/logind.conf.d"/*; do
        [[ -f "$file" ]] || continue
        filename=$(basename "$file")
        if install_file_if_changed "$file" "/etc/systemd/logind.conf.d/$filename"; then
            logind_changed=true
            log_success "$filename (reboot required)"
        else
            log_info "$filename already up to date"
        fi
    done

    # Set flag that reboot is needed (don't restart logind - it kills the session!)
    # Use a flag file since we're running in a subshell
    if $logind_changed; then
        mkdir -p "$HOME/.local/state/dotfiles"
        touch "$HOME/.local/state/dotfiles/.reboot_needed"
    fi
fi
