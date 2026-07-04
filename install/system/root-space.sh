#!/bin/bash
# Root disk space relief
# On machines with a small root partition and a separate /home, keep the two
# biggest root-fillers on /home instead:
#   1. pacman package cache -> /home/pacman-cache (via CacheDir in pacman.conf)
#   2. /opt                 -> /home/opt (via fstab bind mount)
# Idempotent: safe to re-run; skips machines without a separate /home.

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
else
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "Root disk space"

# Only relevant when /home is its own filesystem
if ! findmnt -rn /home >/dev/null; then
    log_info "/home is not a separate partition; nothing to do"
    exit 0
fi

# --- 1. pacman cache on /home ---
PACMAN_CACHE="/home/pacman-cache"

if grep -Eq "^CacheDir\s*=\s*${PACMAN_CACHE}/?\s*$" /etc/pacman.conf; then
    log_info "pacman CacheDir already on /home"
else
    sudo mkdir -p "$PACMAN_CACHE"
    # Migrate anything still in the default cache
    sudo mv /var/cache/pacman/pkg/* "$PACMAN_CACHE"/ 2>/dev/null || true
    if grep -Eq "^#?CacheDir" /etc/pacman.conf; then
        sudo sed -i "s|^#\?CacheDir.*|CacheDir = ${PACMAN_CACHE}/|" /etc/pacman.conf
    else
        sudo sed -i "/^\[options\]/a CacheDir = ${PACMAN_CACHE}/" /etc/pacman.conf
    fi
    log_success "pacman cache moved to $PACMAN_CACHE"
fi

# --- 2. /opt bind-mounted from /home/opt ---
if findmnt -rn /opt >/dev/null; then
    log_info "/opt already mounted from /home"
elif grep -q "^/home/opt[[:space:]]" /etc/fstab; then
    log_info "/opt bind mount already in fstab; mounting"
    sudo mount /opt 2>/dev/null || true
else
    log_info "Moving /opt to /home/opt..."
    sudo mkdir -p /home/opt
    if sudo cp -a /opt/. /home/opt/; then
        echo "/home/opt /opt none bind 0 0" | sudo tee -a /etc/fstab >/dev/null
        sudo systemctl daemon-reload
        # Copy verified; clear originals so root actually gets the space back
        sudo find /opt -mindepth 1 -maxdepth 1 -exec rm -rf {} +
        sudo mount /opt
        log_success "/opt now lives on /home (bind mount)"
    else
        log_error "Copying /opt to /home/opt failed; /opt left untouched"
        exit 1
    fi
fi
