#!/bin/bash
# Shell setup operations (zsh, oh-my-zsh, plugins)

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
PLUGINS_FILE="$DOTFILES_DIR/packages/zsh-plugins.package"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Check if zsh is installed, install if missing
check_zsh() {
    if command -v zsh &>/dev/null; then
        return 0
    fi
    
    log_warning "zsh is not installed"
    
    # Ask user if they want to install
    if ! confirm "Install zsh using pacman?"; then
        graceful_error "zsh not installed" "Install manually or run: dotfiles shell setup"
        return 1
    fi
    
    # Install zsh using pacman
    log_info "Installing zsh..."
    if sudo pacman -S --needed --noconfirm zsh; then
        # Verify installation
        if command -v zsh &>/dev/null; then
            log_success "zsh is now installed"
            return 0
        else
            log_error "zsh installation completed but command not found"
            log_info "You may need to update your PATH or restart your shell"
            return 1
        fi
    else
        log_error "Failed to install zsh"
        return 1
    fi
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

# Check if Starship is installed
check_starship() {
    if command -v starship &>/dev/null; then
        return 0
    fi
    
    log_warning "Starship is not installed"
    
    # Ask user if they want to install
    if ! confirm "Install Starship? (via pacman or cargo)"; then
        log_info "Skipping Starship installation"
        return 0
    fi
    
    # Try pacman first (Arch Linux)
    if command -v pacman &>/dev/null; then
        log_info "Installing Starship via pacman..."
        if sudo pacman -S --needed --noconfirm starship; then
            if command -v starship &>/dev/null; then
                log_success "Starship installed"
                return 0
            fi
        fi
    fi
    
    # Fallback to cargo if available
    if command -v cargo &>/dev/null; then
        log_info "Installing Starship via cargo..."
        if cargo install starship --locked; then
            if command -v starship &>/dev/null; then
                log_success "Starship installed"
                return 0
            fi
        fi
    fi
    
    log_warning "Could not install Starship automatically"
    log_info "Install manually: https://starship.rs/guide/#%F0%9F%9A%80-installation"
    return 0  # Don't fail setup if Starship isn't installed
}

# Update plugins array in .zshrc
update_zshrc_plugins() {
    local zshrc_file="$DOTFILES_DIR/stow/shell/.zshrc"
    
    if [[ ! -f "$zshrc_file" ]]; then
        log_warning "Could not find .zshrc file: $zshrc_file"
        return 0  # Don't fail setup
    fi
    
    if [[ ! -f "$PLUGINS_FILE" ]]; then
        log_warning "Plugin list not found, skipping plugin array update"
        return 0
    fi
    
    log_info "Updating plugins array in .zshrc..."
    
    # Built-in Oh My Zsh plugins (always include these)
    local builtin_plugins=("git" "command-not-found" "sudo" "history" "dirhistory")
    
    # Collect external plugins from zsh-plugins.package
    local external_plugins=()
    while IFS= read -r plugin_line; do
        # Skip comments and empty lines
        [[ -z "$plugin_line" ]] && continue
        [[ "$plugin_line" =~ ^#.*$ ]] && continue
        
        local plugin_name=$(echo "$plugin_line" | cut -d':' -f1)
        
        # Only add if plugin is actually installed
        if is_plugin_installed "$plugin_name"; then
            external_plugins+=("$plugin_name")
        fi
    done < "$PLUGINS_FILE"
    
    # Combine all plugins
    local all_plugins=("${builtin_plugins[@]}" "${external_plugins[@]}")
    
    # Create temporary file for new .zshrc
    local temp_file=$(mktemp)
    local in_plugins_array=false
    local plugins_written=false
    
    while IFS= read -r line; do
        # Detect start of plugins array
        if [[ "$line" =~ ^plugins=\( ]]; then
            in_plugins_array=true
            plugins_written=true
            
            # Write plugins array
            echo "plugins=(" >> "$temp_file"
            for plugin in "${all_plugins[@]}"; do
                echo "  $plugin" >> "$temp_file"
            done
            echo ")" >> "$temp_file"
            continue
        fi
        
        # Skip lines inside plugins array until we hit the closing )
        if [[ "$in_plugins_array" == true ]]; then
            if [[ "$line" =~ ^\) ]]; then
                in_plugins_array=false
            fi
            continue
        fi
        
        # Write all other lines
        echo "$line" >> "$temp_file"
    done < "$zshrc_file"
    
    # Replace original file
    if mv "$temp_file" "$zshrc_file"; then
        log_success "Updated plugins array ($((${#all_plugins[@]})) plugins)"
        return 0
    else
        log_error "Failed to update plugins array"
        rm -f "$temp_file"
        return 0  # Don't fail setup
    fi
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
    
    # Update plugins array in .zshrc
    update_zshrc_plugins
    
    echo
    
    # Check/install Starship
    check_starship
    
    echo
    
    # Set default shell
    set_default_shell
    
    echo
    log_success "Shell setup complete"
}

# Show shell version information
shell_show_version() {
    if command -v zsh &>/dev/null; then
        local version=$(zsh --version | cut -d' ' -f2)
        show_info "Version" "$version"
    else
        show_info "Status" "not installed"
    fi
}

# Shell management menu
shell_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"

    while true; do
        clear_screen "Shell"
        shell_show_version
        echo

        local action=$(choose_option \
            "Setup shell" \
            "Show details" \
            "Back")

        [[ -z "$action" ]] && return

        case "$action" in
            "Setup shell")
                run_operation "" shell_setup
                ;;
            "Show details")
                run_operation "" shell_status
                ;;
            "Back")
                return
                ;;
        esac
    done
}

# Show shell status
shell_status() {
    log_section "Shell Status"

    # Check zsh installation
    if ! command -v zsh &>/dev/null; then
        log_error "zsh is not installed"
        return 1
    fi

    # Check default shell
    local current_shell=$(getent passwd "$USER" | cut -d: -f7 2>/dev/null || echo "$SHELL")
    local shell_name=$(basename "$current_shell")
    if [[ "$shell_name" == "zsh" ]]; then
        show_info "Default shell" "$shell_name $(gum style --foreground 2 '✓')"
    else
        show_info "Default shell" "$shell_name $(gum style --foreground 3 '(not zsh)')"
        echo
    fi

    # Check Oh My Zsh installation
    echo
    if is_omz_installed; then
        log_success "Oh My Zsh is installed"
    else
        log_warning "Oh My Zsh is not installed"
        echo
    fi

    # Check shell configuration files
    echo
    log_info "Configuration files:"
    local config_files=("$HOME/.zshrc" "$HOME/.profile" "$HOME/.zprofile")
    local all_linked=true
    for config_file in "${config_files[@]}"; do
        if [[ -L "$config_file" ]]; then
            if [[ -e "$config_file" ]]; then
                echo "  $(gum style --foreground 2 "✓") $(basename "$config_file") (linked)"
            else
                echo "  $(gum style --foreground 1 "✗") $(basename "$config_file") (broken symlink)"
                all_linked=false
            fi
        elif [[ -f "$config_file" ]]; then
            echo "  $(gum style --foreground 8 "○") $(basename "$config_file") (not linked)"
            all_linked=false
        fi
    done
    echo

    # List plugin status
    if is_omz_installed && [[ -f "$PLUGINS_FILE" ]]; then
        log_info "Plugins:"
        local -a installed_plugins=()
        local -a missing_plugins=()

        while IFS= read -r plugin_line; do
            [[ -z "$plugin_line" ]] && continue
            [[ "$plugin_line" =~ ^#.*$ ]] && continue

            local plugin_name=$(echo "$plugin_line" | cut -d':' -f1)
            if is_plugin_installed "$plugin_name"; then
                installed_plugins+=("$plugin_name")
            else
                missing_plugins+=("$plugin_name")
            fi
        done < "$PLUGINS_FILE"

        if [[ ${#installed_plugins[@]} -gt 0 ]]; then
            for plugin in "${installed_plugins[@]}"; do
                echo "  $(gum style --foreground 2 "✓") $plugin"
            done
        fi

        if [[ ${#missing_plugins[@]} -gt 0 ]]; then
            for plugin in "${missing_plugins[@]}"; do
                echo "  $(gum style --foreground 3 "○") $plugin (not installed)"
            done
            echo
        elif [[ ${#installed_plugins[@]} -eq 0 ]]; then
            echo "  $(gum style --foreground 8 "No plugins configured")"
            echo
        else
            log_success "All plugins are installed"
            echo
        fi
    fi
    
    # Check Starship (user said this adds value)
    if command -v starship &>/dev/null; then
        local starship_config="$HOME/.config/starship.toml"
        if [[ -f "$starship_config" ]]; then
            show_info "Starship config" "$(gum style --foreground 2 '✓ Configured')"
        else
            show_info "Starship config" "$(gum style --foreground 3 '✗ Not configured')"
            echo
            log_info "Starship is installed but not configured"
            echo
        fi
    else
        show_info "Starship" "$(gum style --foreground 8 'Not installed')"
        echo
    fi
}

