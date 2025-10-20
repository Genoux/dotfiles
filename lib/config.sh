#!/bin/bash
# Config management operations (stow/unstow dotfiles)

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
STOW_DIR="$DOTFILES_DIR/stow"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Check if stow is available
check_stow() {
    if ! command -v stow &>/dev/null; then
        graceful_error "stow not found" "Install with: sudo pacman -S stow"
        return 1
    fi
    return 0
}

# Get list of available configs
get_configs() {
    cd "$STOW_DIR"
    find . -maxdepth 1 -type d ! -name ".*" ! -name "manage-configs.sh" ! -path "." | sed 's|^\./||' | sort
}

# Check if config is linked
is_config_linked() {
    local config="$1"
    
    case "$config" in
        "system")
            # Check if any system config file is linked
            if [[ -d "$STOW_DIR/system/.config" ]]; then
                for file in "$STOW_DIR/system/.config"/*; do
                    local basename=$(basename "$file")
                    if [[ -L "$HOME/.config/$basename" ]]; then
                        return 0
                    fi
                done
            fi
            return 1
            ;;
        "shell")
            [[ -L "$HOME/.zshrc" ]] || [[ -L "$HOME/.profile" ]] || [[ -L "$HOME/.zprofile" ]]
            ;;
        "applications")
            if [[ -d "$HOME/.local/share/applications" ]]; then
                find "$HOME/.local/share/applications" -type l -exec readlink {} \; 2>/dev/null | grep -q "dotfiles/stow/applications"
            else
                return 1
            fi
            ;;
        "scripts")
            if [[ -d "$HOME/.local/bin" ]]; then
                find "$HOME/.local/bin" -type l -exec readlink {} \; 2>/dev/null | grep -q "dotfiles/stow/scripts"
            else
                return 1
            fi
            ;;
        *)
            [[ -L "$HOME/.config/$config" ]] || find "$HOME/.config" "$HOME/.local" -maxdepth 3 -type l 2>/dev/null | xargs readlink 2>/dev/null | grep -q "dotfiles/stow/$config"
            ;;
    esac
}

# Link a config
config_link() {
    local config="$1"
    local force="${2:-false}"
    
    check_stow || return 1
    
    if [[ ! -d "$STOW_DIR/$config" ]]; then
        graceful_error "Config not found: $config"
        return 1
    fi
    
    cd "$STOW_DIR"
    
    # Check if already linked (for messaging only)
    local already_linked=false
    if is_config_linked "$config"; then
        already_linked=true
    fi
    
    # Special handling for scripts
    if [[ "$config" == "scripts" ]]; then
        # Make scripts executable
        if [[ -d "$STOW_DIR/scripts/.local/bin" ]]; then
            find "$STOW_DIR/scripts/.local/bin" -type f -exec chmod +x {} \;
            log_info "Made scripts executable"
        fi
    fi
    
    # Stow the config (always restow to pick up new files)
    if $already_linked; then
        log_info "Re-stowing $config (updating symlinks)..."
    else
        log_info "Linking $config..."
    fi
    
    # Try with --adopt to handle conflicts (adopts existing files into stow dir)
    local stow_output
    if stow_output=$(stow -R --adopt -t "$HOME" "$config" 2>&1); then
        if $already_linked; then
            log_success "$config re-stowed successfully"
        else
            log_success "$config linked successfully"
        fi
        
        # Post-link actions
        case "$config" in
            "applications")
                if command -v update-desktop-database &>/dev/null; then
                    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
                    log_info "Updated desktop database"
                fi
                ;;
            "system")
                # Enable user systemd services (only if not already enabled/running)
                if [[ -d "$HOME/.config/systemd/user" ]]; then
                    log_info "Checking user systemd services..."
                    for service in "$HOME/.config/systemd/user"/*.service; do
                        if [[ -f "$service" ]]; then
                            local service_name=$(basename "$service")
                            
                            # Check if already enabled
                            if systemctl --user is-enabled "$service_name" &>/dev/null; then
                                # Check if running
                                if systemctl --user is-active "$service_name" &>/dev/null; then
                                    log_info "$service_name already enabled and running"
                                else
                                    # Enabled but not running - start it
                                    systemctl --user start "$service_name" 2>/dev/null && \
                                        log_success "Started $service_name" || \
                                        log_warning "Could not start $service_name"
                                fi
                            else
                                # Not enabled - enable and start
                                systemctl --user enable --now "$service_name" 2>/dev/null && \
                                    log_success "Enabled and started $service_name" || \
                                    log_warning "Could not enable $service_name"
                            fi
                        fi
                    done
                fi
                ;;
        esac
        
        return 0
    else
        graceful_error "Failed to link $config" "$stow_output"
        return 1
    fi
}

# Unlink a config
config_unlink() {
    local config="$1"
    
    check_stow || return 1
    
    if [[ ! -d "$STOW_DIR/$config" ]]; then
        graceful_error "Config not found: $config"
        return 1
    fi
    
    cd "$STOW_DIR"
    
    # Pre-unlink actions
    case "$config" in
        "system")
            # Disable user systemd services first
            if [[ -d "$HOME/.config/systemd/user" ]]; then
                log_info "Disabling user systemd services..."
                for service in "$HOME/.config/systemd/user"/*.service; do
                    if [[ -f "$service" ]]; then
                        local service_name=$(basename "$service")
                        systemctl --user disable --now "$service_name" 2>/dev/null && \
                            log_success "Disabled $service_name" || \
                            log_warning "Could not disable $service_name"
                    fi
                done
            fi
            ;;
    esac
    
    log_info "Unlinking $config..."
    if stow -D -t "$HOME" "$config" 2>/dev/null; then
        log_success "$config unlinked successfully"
        return 0
    else
        log_warning "$config was not linked or already unlinked"
        return 1
    fi
}

# Link all configs
config_link_all() {
    local force="${1:-false}"
    
    log_section "Linking All Configs"
    
    local configs=($(get_configs))
    local failed=0
    
    for config in "${configs[@]}"; do
        if ! config_link "$config" "$force"; then
            ((failed++))
        fi
    done
    
    echo
    if [[ $failed -eq 0 ]]; then
        log_success "All configs linked successfully"
    else
        log_warning "$failed config(s) failed to link"
    fi
}

# Unlink all configs
config_unlink_all() {
    log_section "Unlinking All Configs"
    
    local configs=($(get_configs))
    local failed=0
    
    for config in "${configs[@]}"; do
        if ! config_unlink "$config"; then
            ((failed++))
        fi
    done
    
    echo
    if [[ $failed -eq 0 ]]; then
        log_success "All configs unlinked successfully"
    else
        log_warning "$failed config(s) failed to unlink"
    fi
}

# Show config status
config_status() {
    log_section "Config Status"
    
    local configs=($(get_configs))
    local linked_count=0
    
    for config in "${configs[@]}"; do
        if is_config_linked "$config"; then
            if command -v gum &>/dev/null; then
                echo "$(gum style --foreground 10 "✓ $config")$(gum style --foreground 240 " (linked)")"
            else
                echo -e "${GREEN}✓ $config${NC} ${GRAY}(linked)${NC}"
            fi
            ((linked_count++))
        else
            if command -v gum &>/dev/null; then
                echo "$(gum style --foreground 240 "○ $config (not linked)")"
            else
                echo -e "${GRAY}○ $config${NC} ${GRAY}(not linked)${NC}"
            fi
        fi
    done
    
    echo
    show_info "Total configs" "${#configs[@]}"
    show_info "Linked" "$linked_count"
    show_info "Not linked" "$((${#configs[@]} - linked_count))"
}

# Interactive config selection
config_select() {
    local action="$1"  # link or unlink
    
    local configs=($(get_configs))
    
    if [[ ${#configs[@]} -eq 0 ]]; then
        log_error "No configs found in $STOW_DIR"
        return 1
    fi
    
    # Simple config list
    local display_configs=("${configs[@]}")
    display_configs+=("Back")
    
    clear_screen "Select Config"
    local choice=$(choose_option "${display_configs[@]}")
    
    [[ -z "$choice" ]] && return 0  # ESC pressed
    
    if [[ "$choice" == "Back" ]]; then
        return 0
    fi
    
    if [[ "$action" == "link" ]]; then
        config_link "$choice"
    else
        config_unlink "$choice"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

