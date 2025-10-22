#!/bin/bash
# Shell setup operations (zsh, oh-my-zsh, plugins)

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
PLUGINS_FILE="$DOTFILES_DIR/zsh-plugins.txt"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Check if zsh is installed
check_zsh() {
    if ! command -v zsh &>/dev/null; then
        graceful_error "zsh not installed" "Install with: sudo pacman -S zsh"
        return 1
    fi
    return 0
}

# Check if Oh My Zsh is installed
is_omz_installed() {
    [[ -d "$HOME/.oh-my-zsh" ]]
}

# Install Oh My Zsh
install_omz() {
    if is_omz_installed; then
        log_info "Oh My Zsh is already installed"
        return 0
    fi
    
    log_info "Installing Oh My Zsh..."
    echo

    log_info "Downloading installer..."
    local temp_file=$(mktemp)
    if curl -# -fL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh > "$temp_file"; then
        echo
        # Run installer in unattended mode
        run_with_spinner "Installing Oh My Zsh" \
            env RUNZSH=no CHSH=no sh "$temp_file"
        
        if is_omz_installed; then
            log_success "Oh My Zsh installed"
            rm -f "$temp_file"
            return 0
        else
            log_error "Oh My Zsh installation failed"
            rm -f "$temp_file"
            return 1
        fi
    else
        log_error "Failed to download Oh My Zsh installer"
        rm -f "$temp_file"
        return 1
    fi
}

# Check if plugin is installed
is_plugin_installed() {
    local plugin="$1"
    [[ -d "$HOME/.oh-my-zsh/custom/plugins/$plugin" ]]
}

# Install zsh plugins
install_plugins() {
    if ! is_omz_installed; then
        graceful_error "Oh My Zsh not installed" "Run: dotfiles shell setup"
        return 1
    fi
    
    if [[ ! -f "$PLUGINS_FILE" ]]; then
        graceful_error "Plugin list not found: $PLUGINS_FILE"
        return 1
    fi
    
    log_info "Installing zsh plugins..."
    
    local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
    ensure_directory "$plugins_dir"
    
    local installed=0
    local skipped=0
    local failed=0
    
    while IFS= read -r plugin_line; do
        # Skip comments and empty lines
        [[ -z "$plugin_line" ]] && continue
        [[ "$plugin_line" =~ ^#.*$ ]] && continue
        
        local plugin_name=$(echo "$plugin_line" | cut -d':' -f1)
        local plugin_url=$(echo "$plugin_line" | cut -d':' -f2-)
        local plugin_dir="$plugins_dir/$plugin_name"
        
        if is_plugin_installed "$plugin_name"; then
            log_info "  ○ $plugin_name (already installed)"
            ((skipped++))
            continue
        fi
        
        log_info "  → Installing $plugin_name..."
        if git clone --depth=1 --progress "$plugin_url" "$plugin_dir" 2>&1 | grep -E 'Cloning|Receiving|remote:'; then
            log_success "  ✓ $plugin_name installed"
            ((installed++))
        else
            log_error "  ✗ $plugin_name failed"
            ((failed++))
        fi
    done < "$PLUGINS_FILE"
    
    echo
    show_info "Installed" "$installed"
    show_info "Already installed" "$skipped"
    if [[ $failed -gt 0 ]]; then
        show_info "Failed" "$failed"
    fi
    
    return 0
}

# Set zsh as default shell
set_default_shell() {
    local zsh_path=$(which zsh)
    local current_shell=$(getent passwd "$USER" | cut -d: -f7 2>/dev/null || echo "$SHELL")
    
    if [[ "$current_shell" == "$zsh_path" ]]; then
        log_success "zsh is already the default shell"
        return 0
    fi
    
    log_info "Setting zsh as default shell..."
    
    if confirm "Change default shell to zsh? (requires password)"; then
        if chsh -s "$zsh_path"; then
            log_success "Default shell changed to zsh"
            log_info "Log out and back in for changes to take effect"
            return 0
        else
            graceful_error "Failed to change default shell" "Try manually: chsh -s $zsh_path"
            return 1
        fi
    else
        log_info "Skipped changing default shell"
        return 0
    fi
}

# Complete shell setup
shell_setup() {
    log_section "Shell Setup"
    
    # Check prerequisites
    check_zsh || return 1
    
    echo
    
    # Install Oh My Zsh
    install_omz || return 1
    
    echo
    
    # Install plugins
    install_plugins
    
    echo
    
    # Set default shell
    set_default_shell
    
    echo
    log_success "Shell setup complete"
}

# Show shell status
shell_status() {
    log_section "Shell Status"
    
    # Check zsh
    if command -v zsh &>/dev/null; then
        show_info "zsh" "✓ Installed ($(zsh --version | cut -d' ' -f2))"
    else
        show_info "zsh" "✗ Not installed"
    fi
    
    # Check Oh My Zsh
    if is_omz_installed; then
        show_info "Oh My Zsh" "✓ Installed"
    else
        show_info "Oh My Zsh" "✗ Not installed"
    fi
    
    # Check default shell
    local current_shell=$(getent passwd "$USER" | cut -d: -f7 2>/dev/null || echo "$SHELL")
    local shell_name=$(basename "$current_shell")
    show_info "Default shell" "$shell_name"
    
    # Count plugins
    if is_omz_installed && [[ -f "$PLUGINS_FILE" ]]; then
        local total_plugins=$(grep -cvE '^#|^$' "$PLUGINS_FILE")
        local installed_plugins=0
        
        while IFS= read -r plugin_line; do
            [[ -z "$plugin_line" ]] && continue
            [[ "$plugin_line" =~ ^#.*$ ]] && continue
            
            local plugin_name=$(echo "$plugin_line" | cut -d':' -f1)
            if is_plugin_installed "$plugin_name"; then
                ((installed_plugins++))
            fi
        done < "$PLUGINS_FILE"
        
        show_info "Plugins" "$installed_plugins/$total_plugins installed"
    fi
}

