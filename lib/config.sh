#!/bin/bash
# Config management operations (stow/unstow dotfiles)
# Requires: gum (charmbracelet/gum)

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
STOW_DIR="$DOTFILES_DIR/stow"

# Validate stow directory exists
if [[ ! -d "$STOW_DIR" ]]; then
    echo "ERROR: Stow directory not found: $STOW_DIR"
    echo "Your dotfiles repository may be corrupted or incomplete."
    exit 1
fi

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

# Interactive config management with checkboxes
config_manage_interactive() {
    check_stow || return 1

    local configs=($(get_configs))
    local options=()

    # Build options and pre-selections simultaneously
    local pre_selected=()
    for config in "${configs[@]}"; do
        if is_config_linked "$config"; then
            local option="$config (linked)"
            options+=("$option")
            pre_selected+=("$option")
        else
            options+=("$config")
        fi
    done

    # Interactive selection with gum
    clear
    echo
    printf "\033[94mSelect configs to link\033[0m\n"
    printf "\033[90m(space to toggle, enter to apply - unchecked will be unlinked)\033[0m\n"
    echo

    # Build gum command with pre-selections
    local gum_args=(--no-limit --height 15 --no-show-help)
    for item in "${pre_selected[@]}"; do
        gum_args+=(--selected="$item")
    done

    # Execute gum choose with pre-selections
    local selected=()
    readarray -t selected < <(gum choose "${gum_args[@]}" "${options[@]}")
    local gum_exit=$?

    # Check if user cancelled (ESC pressed)
    if [[ $gum_exit -ne 0 ]]; then
        # Return 1 to skip "Press Enter"
        return 1
    fi

    # If nothing selected but we had options, user cancelled
    if [[ ${#selected[@]} -eq 0 && ${#options[@]} -gt 0 ]]; then
        # Return 1 to skip "Press Enter"
        return 1
    fi

    echo

    # Confirmation before applying changes
    local will_link=0
    local will_unlink=0

    for config in "${configs[@]}"; do
        local is_selected=false
        for sel in "${selected[@]}"; do
            local sel_name="${sel%% (*}"
            if [[ "$sel_name" == "$config" ]]; then
                is_selected=true
                break
            fi
        done

        if $is_selected; then
            if ! is_config_linked "$config"; then
                ((will_link++))
            fi
        else
            if is_config_linked "$config"; then
                ((will_unlink++))
            fi
        fi
    done

    if [[ $will_link -gt 0 ]] || [[ $will_unlink -gt 0 ]]; then
        log_warning "Changes to apply:"
        [[ $will_link -gt 0 ]] && echo "  • Will link: $will_link configs"
        [[ $will_unlink -gt 0 ]] && echo "  • Will unlink: $will_unlink configs"
        echo

        if ! confirm "Apply these changes?"; then
            # Return 1 to skip "Press Enter"
            return 1
        fi
    fi

    echo
    log_section "Applying Changes"

    # Clean up orphaned symlinks first
    config_cleanup_orphans

    # Determine what to link and unlink
    local to_link=()
    local to_unlink=()

    for config in "${configs[@]}"; do
        local config_option="$config"
        if is_config_linked "$config"; then
            config_option="$config (linked)"
        fi

        local is_selected=false
        for sel in "${selected[@]}"; do
            local sel_name="${sel%% (*}"
            if [[ "$sel_name" == "$config" ]]; then
                is_selected=true
                break
            fi
        done

        if $is_selected; then
            if ! is_config_linked "$config"; then
                to_link+=("$config")
            fi
        else
            if is_config_linked "$config"; then
                to_unlink+=("$config")
            fi
        fi
    done

    # Apply changes
    local changes=0

    if [[ ${#to_link[@]} -gt 0 ]]; then
        log_info "Linking ${#to_link[@]} configs..."
        echo
        for config in "${to_link[@]}"; do
            config_link "$config"
            ((changes++))
        done
        echo
    fi

    if [[ ${#to_unlink[@]} -gt 0 ]]; then
        log_info "Unlinking ${#to_unlink[@]} configs..."
        echo
        for config in "${to_unlink[@]}"; do
            config_unlink "$config"
            ((changes++))
        done
        echo
    fi

    if [[ $changes -eq 0 ]]; then
        log_success "No changes needed"
    else
        log_success "Applied $changes changes"
    fi
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
        
        # Handle absolute symlink in source - remove it (dotfiles command is managed separately)
        local dotfiles_symlink="$STOW_DIR/scripts/.local/bin/dotfiles"
        if [[ -L "$dotfiles_symlink" ]]; then
            local symlink_target=$(readlink "$dotfiles_symlink")
            if [[ "$symlink_target" == /* ]]; then
                # Absolute symlink - remove it, dotfiles command is installed separately
                log_info "Removing absolute symlink (dotfiles command is managed separately)..."
                rm "$dotfiles_symlink"
            fi
        fi
    fi
    
    # Stow the config (always restow to pick up new files)
    # Use --adopt to move existing files into stow directory (repo is source of truth)
    if $already_linked; then
        log_info "Re-stowing $config (updating symlinks)..."
    else
        log_info "Linking $config..."
    fi

    # Try stow with --adopt flag to handle conflicts (moves existing files into stow dir)
    local stow_output
    local stow_success=false

    if stow_output=$(stow -R --adopt -t "$HOME" "$config" 2>&1); then
        if $already_linked; then
            log_success "$config re-stowed successfully"
        else
            log_success "$config linked successfully"
        fi
        stow_success=true
    elif echo "$stow_output" | grep -q "source is an absolute symlink"; then
        # Handle absolute symlink in source directory
        log_warning "$config has absolute symlink in source"
        
        # Extract the problematic symlink path from error message
        local symlink_path=$(echo "$stow_output" | grep -oP "dotfiles/stow/$config/[^ ]+")
        if [[ -n "$symlink_path" ]]; then
            local full_path="$DOTFILES_DIR/$symlink_path"
            if [[ -L "$full_path" ]]; then
                log_info "Removing absolute symlink: $symlink_path"
                rm "$full_path"
                
                # Try stow again
                if stow_output=$(stow -R --adopt -t "$HOME" "$config" 2>&1); then
                    log_success "$config linked successfully"
                    stow_success=true
                else
                    graceful_error "Failed to link $config after removing symlink" "$stow_output"
                    return 1
                fi
            fi
        else
            graceful_error "Failed to link $config" "$stow_output"
            return 1
        fi
    else
        graceful_error "Failed to link $config" "$stow_output"
        return 1
    fi

    # Post-link actions (run after successful stow)
    if $stow_success; then
        case "$config" in
            "applications")
                if command -v update-desktop-database &>/dev/null; then
                    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
                    log_info "Updated desktop database"
                fi
                ;;
            "ags")
                # Create symlink for AGS TypeScript types
                local ags_config_dir="$HOME/.config/ags"
                local ags_node_modules="$ags_config_dir/node_modules"
                local ags_symlink="$ags_node_modules/ags"
                local ags_source="/usr/share/ags/js"

                if [[ -d "$ags_config_dir" ]]; then
                    # Ensure node_modules directory exists
                    if [[ ! -d "$ags_node_modules" ]]; then
                        mkdir -p "$ags_node_modules"
                        log_info "Created node_modules directory for AGS"
                    fi

                    # Create symlink if it doesn't exist or is broken
                    if [[ -L "$ags_symlink" ]]; then
                        if [[ -e "$ags_symlink" ]]; then
                            log_info "AGS types symlink already exists"
                        else
                            log_info "Removing broken symlink and recreating..."
                            rm "$ags_symlink"
                            ln -s "$ags_source" "$ags_symlink"
                            log_success "AGS types symlink created"
                        fi
                    elif [[ -e "$ags_symlink" ]]; then
                        log_warning "File exists at $ags_symlink (not a symlink), skipping"
                    else
                        if [[ -d "$ags_source" ]]; then
                            ln -s "$ags_source" "$ags_symlink"
                            log_success "AGS types symlink created"
                        else
                            log_warning "AGS source directory not found at $ags_source, skipping symlink"
                        fi
                    fi
                fi
                ;;
        esac

        # Enable user systemd services if present (for any config that has them)
        if [[ -d "$HOME/.config/systemd/user" ]]; then
            for service in "$HOME/.config/systemd/user"/*.service; do
                if [[ -f "$service" ]]; then
                    local service_name=$(basename "$service")

                    # Check if this service was just linked by this config
                    if readlink "$service" 2>/dev/null | grep -q "dotfiles/stow/$config"; then
                        # Check if already enabled
                        if systemctl --user is-enabled "$service_name" &>/dev/null; then
                            if systemctl --user is-active "$service_name" &>/dev/null; then
                                log_info "$service_name already enabled and running, restarting to apply changes..."
                                systemctl --user restart "$service_name" 2>/dev/null && \
                                    log_success "Restarted $service_name" || \
                                    log_warning "Could not restart $service_name"
                            else
                                systemctl --user start "$service_name" 2>/dev/null && \
                                    log_success "Started $service_name" || \
                                    log_warning "Could not start $service_name"
                            fi
                        else
                            systemctl --user enable --now "$service_name" 2>/dev/null && \
                                log_success "Enabled and started $service_name" || \
                                log_warning "Could not enable $service_name"
                        fi
                    fi
                fi
            done
        fi
    fi

    return 0
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
    
    # Pre-unlink actions - disable user systemd services if they belong to this config
    if [[ -d "$HOME/.config/systemd/user" ]]; then
        for service in "$HOME/.config/systemd/user"/*.service; do
            if [[ -f "$service" ]]; then
                # Check if this service belongs to the config being unlinked
                if readlink "$service" 2>/dev/null | grep -q "dotfiles/stow/$config"; then
                    local service_name=$(basename "$service")
                    systemctl --user disable --now "$service_name" 2>/dev/null && \
                        log_success "Disabled $service_name" || \
                        log_warning "Could not disable $service_name"
                fi
            fi
        done
    fi
    
    log_info "Unlinking $config..."
    if stow -D -t "$HOME" "$config" 2>/dev/null; then
        log_success "$config unlinked successfully"
        return 0
    else
        log_warning "$config was not linked or already unlinked"
        return 1
    fi
}

# Clean up orphaned symlinks from deleted stow packages
config_cleanup_orphans() {
    log_info "Checking for orphaned symlinks..."

    local orphans=()

    # Check top-level .config directories only (where stow creates links)
    if [[ -d "$HOME/.config" ]]; then
        while IFS= read -r -d '' symlink; do
            local target=$(readlink "$symlink" 2>/dev/null)
            [[ -z "$target" ]] && continue

            if [[ "$target" == *"dotfiles/stow/"* ]]; then
                local stow_package=$(echo "$target" | grep -oP 'dotfiles/stow/\K[^/]+')
                if [[ -n "$stow_package" ]] && [[ ! -d "$STOW_DIR/$stow_package" ]]; then
                    orphans+=("$symlink")
                fi
            fi
        done < <(find "$HOME/.config" -maxdepth 1 -type l -print0 2>/dev/null)
    fi

    # Check .local/bin and .local/share
    for subdir in bin share; do
        if [[ -d "$HOME/.local/$subdir" ]]; then
            while IFS= read -r -d '' symlink; do
                local target=$(readlink "$symlink" 2>/dev/null)
                [[ -z "$target" ]] && continue

                if [[ "$target" == *"dotfiles/stow/"* ]]; then
                    local stow_package=$(echo "$target" | grep -oP 'dotfiles/stow/\K[^/]+')
                    if [[ -n "$stow_package" ]] && [[ ! -d "$STOW_DIR/$stow_package" ]]; then
                        orphans+=("$symlink")
                    fi
                fi
            done < <(find "$HOME/.local/$subdir" -maxdepth 2 -type l -print0 2>/dev/null)
        fi
    done

    # Check shell RC files
    for rc_file in "$HOME/.zshrc" "$HOME/.profile" "$HOME/.zprofile"; do
        if [[ -L "$rc_file" ]]; then
            local target=$(readlink "$rc_file" 2>/dev/null)
            if [[ "$target" == *"dotfiles/stow/"* ]]; then
                local stow_package=$(echo "$target" | grep -oP 'dotfiles/stow/\K[^/]+')
                if [[ -n "$stow_package" ]] && [[ ! -d "$STOW_DIR/$stow_package" ]]; then
                    orphans+=("$rc_file")
                fi
            fi
        fi
    done

    # Remove orphaned symlinks
    if [[ ${#orphans[@]} -gt 0 ]]; then
        log_warning "Found ${#orphans[@]} orphaned symlink(s) from deleted stow packages"
        for orphan in "${orphans[@]}"; do
            local rel_path="${orphan#$HOME/}"
            rm "$orphan"
            log_info "  Removed: ~/$rel_path"
        done
        log_success "Cleaned up ${#orphans[@]} orphaned symlink(s)"
    else
        log_success "No orphaned symlinks found"
    fi

    echo
}

# Link all configs
config_link_all() {
    local force="${1:-false}"

    log_section "Linking All Configs"

    # Clean up orphaned symlinks from deleted stow packages
    config_cleanup_orphans

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

# Check if symlink is broken
is_symlink_broken() {
    local path="$1"
    if [[ -L "$path" ]]; then
        [[ ! -e "$path" ]]
    else
        return 1
    fi
}

# Show config status
config_status() {
    log_section "Config Status"
    
    local configs=($(get_configs))
    local linked_count=0
    local broken_count=0
    local -a broken_configs=()
    
    for config in "${configs[@]}"; do
        local is_linked=false
        local is_broken=false
        
        # Check link status and detect broken symlinks
        case "$config" in
            "shell")
                if [[ -L "$HOME/.zshrc" ]] || [[ -L "$HOME/.profile" ]] || [[ -L "$HOME/.zprofile" ]]; then
                    is_linked=true
                    if is_symlink_broken "$HOME/.zshrc" || is_symlink_broken "$HOME/.profile" || is_symlink_broken "$HOME/.zprofile"; then
                        is_broken=true
                    fi
                fi
                ;;
            "applications")
                if [[ -d "$HOME/.local/share/applications" ]]; then
                    if find "$HOME/.local/share/applications" -type l -exec readlink {} \; 2>/dev/null | grep -q "dotfiles/stow/applications"; then
                        is_linked=true
                        # Check for broken symlinks
                        while IFS= read -r symlink; do
                            if is_symlink_broken "$symlink"; then
                                is_broken=true
                                break
                            fi
                        done < <(find "$HOME/.local/share/applications" -type l 2>/dev/null)
                    fi
                fi
                ;;
            "scripts")
                if [[ -d "$HOME/.local/bin" ]]; then
                    if find "$HOME/.local/bin" -type l -exec readlink {} \; 2>/dev/null | grep -q "dotfiles/stow/scripts"; then
                        is_linked=true
                        # Check for broken symlinks
                        while IFS= read -r symlink; do
                            if is_symlink_broken "$symlink"; then
                                is_broken=true
                                break
                            fi
                        done < <(find "$HOME/.local/bin" -type l 2>/dev/null)
                    fi
                fi
                ;;
            *)
                if [[ -L "$HOME/.config/$config" ]]; then
                    is_linked=true
                    if is_symlink_broken "$HOME/.config/$config"; then
                        is_broken=true
                    fi
                elif find "$HOME/.config" "$HOME/.local" -maxdepth 3 -type l 2>/dev/null | xargs readlink 2>/dev/null | grep -q "dotfiles/stow/$config"; then
                    is_linked=true
                    # Check for broken symlinks
                    while IFS= read -r symlink; do
                        if is_symlink_broken "$symlink"; then
                            is_broken=true
                            break
                        fi
                    done < <(find "$HOME/.config" "$HOME/.local" -maxdepth 3 -type l 2>/dev/null | grep -q "dotfiles/stow/$config" || true)
                fi
                ;;
        esac

        # Display status
        if $is_broken; then
            echo "$(status_error) $config$(gum style --foreground 8 " (broken symlink)")"
            broken_configs+=("$config")
            ((broken_count++))
        elif $is_linked; then
            echo "$(status_ok) $config$(gum style --foreground 8 " (linked)")"
            ((linked_count++))
        else
            echo "$(status_neutral) $config (not linked)"
        fi
    done

    # Show issues if any
    if [[ $broken_count -gt 0 ]]; then
        log_warning "Found $broken_count config(s) with broken symlinks:"
        for config in "${broken_configs[@]}"; do
            echo "  $(status_error) $config"
        done
    fi

    # Show actionable info
    local not_linked=$((${#configs[@]} - linked_count - broken_count))
    if [[ $not_linked -gt 0 ]]; then
        log_info "$not_linked config(s) not linked"
    fi
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

# Config management menu
config_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"

    while true; do
        clear_screen "Configs"

        # Show summary only
        local configs=($(get_configs))
        local linked_count=0
        for config in "${configs[@]}"; do
            is_config_linked "$config" && ((linked_count++))
        done
        show_quick_summary "Status" "$linked_count/${#configs[@]} linked"

        local action=$(choose_option \
            "Manage links" \
            "Link all" \
            "Unlink all" \
            "Show details" \
            "Back")

        [[ -z "$action" ]] && return  # ESC pressed

        case "$action" in
            "Manage links")
                run_operation "" config_manage_interactive
                ;;
            "Link all")
                run_operation "" config_link_all
                ;;
            "Unlink all")
                clear_screen
                if confirm "Unlink all configs?"; then
                    config_unlink_all
                    echo
                fi
                pause
                ;;
            "Show details")
                run_operation "" config_status
                ;;
            "Back")
                return
                ;;
        esac
    done
}

