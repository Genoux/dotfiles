#!/bin/bash
# Stow all configs

# Source helpers first
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_INSTALL/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Source config library
source "$DOTFILES_DIR/lib/config.sh"

log_info "Linking all configurations..."

# Link all configs
config_link_all true

echo
log_info "Installing dotfiles command..."

# Ensure ~/.local/bin exists
ensure_directory "$HOME/.local/bin"

# Create symlink to dotfiles command
if [[ -L "$HOME/.local/bin/dotfiles" ]]; then
    log_info "dotfiles command already linked"
elif [[ -e "$HOME/.local/bin/dotfiles" ]]; then
    log_warning "File exists at ~/.local/bin/dotfiles (not a symlink)"
else
    ln -s "$DOTFILES_DIR/dotfiles" "$HOME/.local/bin/dotfiles"
    log_success "dotfiles command installed"
fi

echo
log_info "Setting up AGS TypeScript types..."

# Create symlink for AGS types in node_modules
AGS_CONFIG_DIR="$HOME/.config/ags"
AGS_NODE_MODULES="$AGS_CONFIG_DIR/node_modules"
AGS_SYMLINK="$AGS_NODE_MODULES/ags"
AGS_SOURCE="/usr/share/ags/js"

if [[ -d "$AGS_CONFIG_DIR" ]]; then
    # Ensure node_modules directory exists
    if [[ ! -d "$AGS_NODE_MODULES" ]]; then
        mkdir -p "$AGS_NODE_MODULES"
        log_info "Created node_modules directory for AGS"
    fi
    
    # Create symlink if it doesn't exist or is broken
    if [[ -L "$AGS_SYMLINK" ]]; then
        if [[ -e "$AGS_SYMLINK" ]]; then
            log_info "AGS types symlink already exists"
        else
            log_info "Removing broken symlink and recreating..."
            rm "$AGS_SYMLINK"
            ln -s "$AGS_SOURCE" "$AGS_SYMLINK"
            log_success "AGS types symlink created"
        fi
    elif [[ -e "$AGS_SYMLINK" ]]; then
        log_warning "File exists at $AGS_SYMLINK (not a symlink), skipping"
    else
        if [[ -d "$AGS_SOURCE" ]]; then
            ln -s "$AGS_SOURCE" "$AGS_SYMLINK"
            log_success "AGS types symlink created"
        else
            log_warning "AGS source directory not found at $AGS_SOURCE, skipping symlink"
        fi
    fi
else
    log_warning "AGS config directory not found at $AGS_CONFIG_DIR, skipping types setup"
fi

echo

# Run services setup
if [[ -f "$DOTFILES_INSTALL/config/services.sh" ]]; then
    bash "$DOTFILES_INSTALL/config/services.sh"
else
    log_warning "services.sh not found at $DOTFILES_INSTALL/config/services.sh"
fi

