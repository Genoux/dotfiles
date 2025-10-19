#!/bin/bash
# Stow all configs

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

