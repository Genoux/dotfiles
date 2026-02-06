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
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] zsh is already installed" >> "$DOTFILES_LOG_FILE"
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] zsh is not installed" >> "$DOTFILES_LOG_FILE"

    # Stop monitor temporarily for user prompt
    stop_log_monitor
    log_warning "zsh is not installed"

    # Ask user if they want to install
    if ! confirm "Install zsh using pacman?"; then
        log_error "zsh not installed. Install manually or run: dotfiles shell setup"
        return 1
    fi

    # Restart monitor and install zsh
    start_log_monitor

    if ! run_command_logged "Install zsh" sudo pacman -S --needed --noconfirm zsh; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Install zsh" >> "$DOTFILES_LOG_FILE"
        return 1
    fi

    # Verify installation
    if command -v zsh &>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: zsh is now installed" >> "$DOTFILES_LOG_FILE"
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: zsh command not found after installation" >> "$DOTFILES_LOG_FILE"
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
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Oh My Zsh is already installed" >> "$DOTFILES_LOG_FILE"
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Install Oh My Zsh" >> "$DOTFILES_LOG_FILE"

    local temp_file=$(mktemp)

    # Download installer
    if ! run_command_logged "Download Oh My Zsh installer" curl -fL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$temp_file"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Download Oh My Zsh installer" >> "$DOTFILES_LOG_FILE"
        rm -f "$temp_file"
        return 1
    fi

    # Run installer in unattended mode
    if ! run_command_logged "Install Oh My Zsh" env RUNZSH=no CHSH=no sh "$temp_file"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Install Oh My Zsh" >> "$DOTFILES_LOG_FILE"
        rm -f "$temp_file"
        return 1
    fi

    rm -f "$temp_file"

    # Verify installation
    if is_omz_installed; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Oh My Zsh installed successfully" >> "$DOTFILES_LOG_FILE"
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Oh My Zsh directory not found after installation" >> "$DOTFILES_LOG_FILE"
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
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Oh My Zsh not installed" >> "$DOTFILES_LOG_FILE"
        return 1
    fi

    if [[ ! -f "$PLUGINS_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Plugin list not found" >> "$DOTFILES_LOG_FILE"
        return 1
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Install zsh plugins" >> "$DOTFILES_LOG_FILE"

    local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
    mkdir -p "$plugins_dir"

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
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $plugin_name already installed" >> "$DOTFILES_LOG_FILE"
            ((skipped++))
            continue
        fi

        if run_command_logged "Install plugin: $plugin_name" git clone --depth=1 "$plugin_url" "$plugin_dir"; then
            ((installed++))
        else
            ((failed++))
        fi
    done < "$PLUGINS_FILE"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Install zsh plugins (installed: $installed, skipped: $skipped, failed: $failed)" >> "$DOTFILES_LOG_FILE"

    return 0
}

# Check if Starship is installed
check_starship() {
    if command -v starship &>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starship is already installed" >> "$DOTFILES_LOG_FILE"
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starship is not installed" >> "$DOTFILES_LOG_FILE"

    # Stop monitor temporarily for user prompt
    stop_log_monitor
    log_warning "Starship is not installed"

    # Ask user if they want to install
    if ! confirm "Install Starship? (via pacman or cargo)"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Skipping Starship installation" >> "$DOTFILES_LOG_FILE"
        start_log_monitor
        return 0
    fi

    # Restart monitor
    start_log_monitor

    # Try pacman first (Arch Linux)
    if command -v pacman &>/dev/null; then
        if run_command_logged "Install Starship via pacman" sudo pacman -S --needed --noconfirm starship; then
            if command -v starship &>/dev/null; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Starship installed" >> "$DOTFILES_LOG_FILE"
                return 0
            fi
        fi
    fi

    # Fallback to cargo if available
    if command -v cargo &>/dev/null; then
        if run_command_logged "Install Starship via cargo" cargo install starship --locked; then
            if command -v starship &>/dev/null; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Starship installed" >> "$DOTFILES_LOG_FILE"
                return 0
            fi
        fi
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Could not install Starship automatically" >> "$DOTFILES_LOG_FILE"
    return 0  # Don't fail setup if Starship isn't installed
}

# Check if blur-my-shell extension is installed
check_blur_my_shell() {
    # Check if gnome-extensions command is available
    if ! command -v gnome-extensions &>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] GNOME extensions not available, skipping blur-my-shell" >> "$DOTFILES_LOG_FILE"
        return 0
    fi

    # Check if extension is already installed
    if pacman -Qi gnome-shell-extension-blur-my-shell &>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] blur-my-shell is already installed" >> "$DOTFILES_LOG_FILE"

        # Enable extension if installed
        if ! gnome-extensions list | grep -q "blur-my-shell@aunetx"; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Enabling blur-my-shell extension" >> "$DOTFILES_LOG_FILE"
            gnome-extensions enable blur-my-shell@aunetx &>/dev/null || true
        fi
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] blur-my-shell is not installed" >> "$DOTFILES_LOG_FILE"

    # Check if yay is available
    if ! command -v yay &>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: yay not available, skipping blur-my-shell" >> "$DOTFILES_LOG_FILE"
        return 0
    fi

    # Stop monitor temporarily for user prompt
    stop_log_monitor
    log_warning "blur-my-shell GNOME extension is not installed"

    # Ask user if they want to install
    if ! confirm "Install blur-my-shell extension? (via yay)"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Skipping blur-my-shell installation" >> "$DOTFILES_LOG_FILE"
        start_log_monitor
        return 0
    fi

    # Restart monitor
    start_log_monitor

    # Install via yay
    if run_command_logged "Install blur-my-shell extension" yay -S --needed --noconfirm gnome-shell-extension-blur-my-shell; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: blur-my-shell installed" >> "$DOTFILES_LOG_FILE"

        # Enable the extension
        if command -v gnome-extensions &>/dev/null; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Enabling blur-my-shell extension" >> "$DOTFILES_LOG_FILE"
            gnome-extensions enable blur-my-shell@aunetx &>/dev/null || true
        fi

        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Could not install blur-my-shell" >> "$DOTFILES_LOG_FILE"
        return 0  # Don't fail setup if blur-my-shell isn't installed
    fi
}

# Update plugins array in .zshrc
update_zshrc_plugins() {
    local zshrc_file="$DOTFILES_DIR/stow/shell/.zshrc"

    if [[ ! -f "$zshrc_file" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: .zshrc file not found" >> "$DOTFILES_LOG_FILE"
        return 0  # Don't fail setup
    fi

    if [[ ! -f "$PLUGINS_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Plugin list not found" >> "$DOTFILES_LOG_FILE"
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: Update plugins array in .zshrc" >> "$DOTFILES_LOG_FILE"
    
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
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Updated plugins array ($((${#all_plugins[@]})) plugins)" >> "$DOTFILES_LOG_FILE"
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Update plugins array" >> "$DOTFILES_LOG_FILE"
        rm -f "$temp_file"
        return 0  # Don't fail setup
    fi
}

# Set zsh as default shell
set_default_shell() {
    local zsh_path=$(which zsh)
    local current_shell=$(getent passwd "$USER" | cut -d: -f7 2>/dev/null || echo "$SHELL")

    if [[ "$current_shell" == "$zsh_path" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] zsh is already the default shell" >> "$DOTFILES_LOG_FILE"
        return 0
    fi

    # Stop monitor temporarily for user prompt
    stop_log_monitor
    log_info "Setting zsh as default shell..."

    if confirm "Change default shell to zsh? (requires password)"; then
        # Restart monitor
        start_log_monitor

        if run_command_logged "Change default shell to zsh" sudo chsh -s "$zsh_path" "$USER"; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: Default shell changed to zsh (restart required)" >> "$DOTFILES_LOG_FILE"
            return 0
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: Change default shell" >> "$DOTFILES_LOG_FILE"
            return 1
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Skipped changing default shell" >> "$DOTFILES_LOG_FILE"
        start_log_monitor
        return 0
    fi
}

# Complete shell setup
shell_setup() {
    # Initialize logging and start monitor
    init_logging "shell"
    start_log_monitor

    # Check prerequisites
    check_zsh || {
        finish_logging
        sleep 1
        stop_log_monitor
        return 1
    }

    # Install Oh My Zsh
    install_omz || {
        finish_logging
        sleep 1
        stop_log_monitor
        return 1
    }

    # Install plugins
    install_plugins

    # Update plugins array in .zshrc
    update_zshrc_plugins

    # Check/install Starship
    check_starship

    # Check/install blur-my-shell extension
    check_blur_my_shell

    # Set default shell
    set_default_shell

    # Finish logging and keep monitor visible
    finish_logging
    sleep 2
    stop_log_monitor true

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
    local skip_title="${1:-}"
    [[ -z "$skip_title" ]] && log_section "Shell Status"

    # Check zsh installation
    if ! command -v zsh &>/dev/null; then
        log_error "zsh is not installed"
        return 1
    fi

    # Check default shell
    local current_shell=$(getent passwd "$USER" | cut -d: -f7 2>/dev/null || echo "$SHELL")
    local shell_name=$(basename "$current_shell")
    if [[ "$shell_name" == "zsh" ]]; then
        show_info "Default shell" "$shell_name $(status_ok)"
    else
        show_info "Default shell" "$shell_name $(status_warning) (not zsh)"
    fi

    echo
    
    # Check shell configuration files
    log_info "Configuration files:"
    local config_files=("$HOME/.zshrc" "$HOME/.profile" "$HOME/.zprofile")
    local all_linked=true
    for config_file in "${config_files[@]}"; do
        if [[ -L "$config_file" ]]; then
            if [[ -e "$config_file" ]]; then
                echo "$(status_ok) $(basename "$config_file") (linked)"
            else
                echo "$(status_error) $(basename "$config_file") (broken symlink)"
                all_linked=false
            fi
        elif [[ -f "$config_file" ]]; then
            echo "$(status_neutral) $(basename "$config_file") (not linked)"
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
                echo "$(status_ok) $plugin"
            done
        fi

        if [[ ${#missing_plugins[@]} -gt 0 ]]; then
            for plugin in "${missing_plugins[@]}"; do
                echo "$(status_warning) $plugin (not installed)"
            done
        elif [[ ${#installed_plugins[@]} -eq 0 ]]; then
            echo "$(gum style --foreground 8 "No plugins configured")"
        fi
    fi

    # Check blur-my-shell extension
    if command -v gnome-extensions &>/dev/null; then
        echo
        log_info "GNOME Extensions:"
        if pacman -Qi gnome-shell-extension-blur-my-shell &>/dev/null; then
            if gnome-extensions list 2>/dev/null | grep -q "blur-my-shell@aunetx"; then
                local status=$(gnome-extensions info blur-my-shell@aunetx 2>/dev/null | grep "State:" | awk '{print $2}')
                if [[ "$status" == "ENABLED" ]]; then
                    echo "$(status_ok) blur-my-shell (enabled)"
                else
                    echo "$(status_warning) blur-my-shell (disabled)"
                fi
            else
                echo "$(status_warning) blur-my-shell (installed, not loaded)"
            fi
        else
            echo "$(status_neutral) blur-my-shell (not installed)"
        fi
    fi

    # Check Starship
    # if command -v starship &>/dev/null; then
    #     local starship_config="$HOME/.config/starship.toml"
    #     if [[ -f "$starship_config" ]]; then
    #         show_info "Starship config" "$(status_ok) Configured"
    #     else
    #         show_info "Starship config" "$(status_warning) Not configured"
    #         log_info "Starship is installed but not configured"
    #     fi
    # else
    #     show_info "Starship" "$(gum style --foreground 8 'Not installed')"
    # fi
}

