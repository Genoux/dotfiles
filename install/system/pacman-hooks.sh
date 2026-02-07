#!/bin/bash
# Pacman hooks installer
# Sets up automatic package list synchronization with dotfiles

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

log_info "Configuring pacman hooks for dotfiles sync..."

# Check if pacman is available
if ! command -v pacman &>/dev/null; then
    log_warning "pacman is not available. Skipping pacman hooks installation"
    exit 0
fi

# Create hooks directory if it doesn't exist
if [[ ! -d "/etc/pacman.d/hooks" ]]; then
    log_info "Creating /etc/pacman.d/hooks directory..."
    sudo mkdir -p /etc/pacman.d/hooks
fi

# Install hook files
HOOK_INSTALL="$SYSTEM_DIR/pacman/hooks/dotfiles-sync-install.hook"
HOOK_REMOVE="$SYSTEM_DIR/pacman/hooks/dotfiles-sync-remove.hook"

if [[ ! -f "$HOOK_INSTALL" ]] || [[ ! -f "$HOOK_REMOVE" ]]; then
    log_error "Hook files not found in $SYSTEM_DIR/pacman/hooks/"
    exit 1
fi

log_info "Installing pacman hooks..."
sudo cp "$HOOK_INSTALL" /etc/pacman.d/hooks/
sudo cp "$HOOK_REMOVE" /etc/pacman.d/hooks/
sudo chmod 644 /etc/pacman.d/hooks/dotfiles-sync-*.hook
log_success "Pacman hooks installed"

# Ensure sync script is executable and accessible
SYNC_SCRIPT="$DOTFILES_DIR/stow/scripts/.local/bin/dotfiles-package-sync"
if [[ ! -f "$SYNC_SCRIPT" ]]; then
    log_error "Sync script not found: $SYNC_SCRIPT"
    exit 1
fi

if [[ ! -x "$SYNC_SCRIPT" ]]; then
    log_info "Making sync script executable..."
    chmod +x "$SYNC_SCRIPT"
fi

# Create symlink to /usr/local/bin for global access
if [[ ! -L "/usr/local/bin/dotfiles-package-sync" ]]; then
    log_info "Creating symlink in /usr/local/bin..."
    sudo ln -sf "$SYNC_SCRIPT" /usr/local/bin/dotfiles-package-sync
    log_success "Symlink created: /usr/local/bin/dotfiles-package-sync"
elif [[ "$(readlink /usr/local/bin/dotfiles-package-sync)" != "$SYNC_SCRIPT" ]]; then
    log_info "Updating symlink in /usr/local/bin..."
    sudo ln -sf "$SYNC_SCRIPT" /usr/local/bin/dotfiles-package-sync
    log_success "Symlink updated"
fi

# Verify installation
if [[ -f "/etc/pacman.d/hooks/dotfiles-sync-install.hook" ]] && \
   [[ -f "/etc/pacman.d/hooks/dotfiles-sync-remove.hook" ]] && \
   [[ -L "/usr/local/bin/dotfiles-package-sync" ]]; then
    log_success "Pacman hooks configured successfully"
    echo
    log_info "Package installations and removals will now be automatically synced to:"
    echo "  - $DOTFILES_DIR/packages/arch.package"
    echo "  - $DOTFILES_DIR/packages/aur.package"
else
    log_error "Hook installation verification failed"
    exit 1
fi
