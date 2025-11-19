#!/bin/bash
# Single-theme management with flexible mappings

DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
THEME_DIR="$DOTFILES_DIR/theme"
THEME_CONFIG="$THEME_DIR/gtk.json"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Show current theme information
theme_show_current() {
    # Find scheme file dynamically
    local current_scheme="none"
    if command -v flavours &>/dev/null || [[ -x "$HOME/.cargo/bin/flavours" ]]; then
        local flavours_cmd="flavours"
        [[ ! -x "$(command -v flavours)" ]] && flavours_cmd="$HOME/.cargo/bin/flavours"
        current_scheme=$("$flavours_cmd" current 2>/dev/null || echo "none")
    fi
    
    local scheme_file=""
    if ! scheme_file=$(get_scheme_file); then
        # No scheme file found
        if [[ "$current_scheme" != "none" ]]; then
            show_info "Active theme" "$current_scheme (no file in dotfiles)"
        else
            show_info "Active theme" "none"
        fi
        return
    fi

    if [[ -f "$scheme_file" ]]; then
        local scheme_name=$(grep "^scheme:" "$scheme_file" | cut -d'"' -f2)
        local scheme_author=$(grep "^author:" "$scheme_file" | cut -d'"' -f2)
        show_info "Active theme" "$scheme_name by $scheme_author"
        echo

        # Display Base16 color palette (compact)
        echo -e "${BOLD}Colors:${RESET}"

        # Read colors from scheme
        local base00=$(grep "^base00:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base01=$(grep "^base01:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base02=$(grep "^base02:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base03=$(grep "^base03:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base04=$(grep "^base04:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base05=$(grep "^base05:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base06=$(grep "^base06:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base07=$(grep "^base07:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base08=$(grep "^base08:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base09=$(grep "^base09:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base0A=$(grep "^base0A:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base0B=$(grep "^base0B:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base0C=$(grep "^base0C:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base0D=$(grep "^base0D:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base0E=$(grep "^base0E:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        local base0F=$(grep "^base0F:" "$scheme_file" | awk '{print $2}' | tr -d '"')
        
        # Display as compact rows of colored circles
        printf "→ Accent Colors: "
        printf "\033[38;2;$((16#${base00:0:2}));$((16#${base00:2:2}));$((16#${base00:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base01:0:2}));$((16#${base01:2:2}));$((16#${base01:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base02:0:2}));$((16#${base02:2:2}));$((16#${base02:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base03:0:2}));$((16#${base03:2:2}));$((16#${base03:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base04:0:2}));$((16#${base04:2:2}));$((16#${base04:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base05:0:2}));$((16#${base05:2:2}));$((16#${base05:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base06:0:2}));$((16#${base06:2:2}));$((16#${base06:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base07:0:2}));$((16#${base07:2:2}));$((16#${base07:4:2}))m●\033[0m"
        echo
        printf "→ Grayscale Colors: "
        printf "\033[38;2;$((16#${base08:0:2}));$((16#${base08:2:2}));$((16#${base08:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base09:0:2}));$((16#${base09:2:2}));$((16#${base09:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base0A:0:2}));$((16#${base0A:2:2}));$((16#${base0A:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base0B:0:2}));$((16#${base0B:2:2}));$((16#${base0B:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base0C:0:2}));$((16#${base0C:2:2}));$((16#${base0C:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base0D:0:2}));$((16#${base0D:2:2}));$((16#${base0D:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base0E:0:2}));$((16#${base0E:2:2}));$((16#${base0E:4:2}))m●\033[0m "
        printf "\033[38;2;$((16#${base0F:0:2}));$((16#${base0F:2:2}));$((16#${base0F:4:2}))m●\033[0m"
        echo
    else
        show_info "Active theme" "Scheme file not found"
    fi
}

# Apply flavours theme using base16 scheme
apply_flavours_theme() {
    # Ensure flavours is installed and templates are downloaded
    if ! command -v flavours &>/dev/null && [[ ! -x "$HOME/.cargo/bin/flavours" ]]; then
        log_info "Setting up flavours for the first time..."
        source "$DOTFILES_DIR/lib/flavours-setup.sh"
        if ! flavours_setup; then
            log_warning "Flavours setup failed - skipping auto-generated themes"
            return 0
        fi
        echo
    fi

    # Use flavours from PATH or cargo bin
    local flavours_cmd="flavours"
    if ! command -v flavours &>/dev/null; then
        flavours_cmd="$HOME/.cargo/bin/flavours"
    fi

    log_info "Applying theme with flavours..."

    # Flavours config is managed via stow (stow/flavours/.config/flavours/config.toml)
    # Scheme files are managed via stow (stow/flavours/.config/flavours/schemes/)
    # Just apply the scheme
    if "$flavours_cmd" apply default 2>&1 | while IFS= read -r line; do
        log_info "  $line"
    done; then
        log_success "Flavours theme applied!"
        return 0
    else
        log_error "Failed to apply flavours theme"
        log_info "Some apps may need custom templates - check stow/flavours/.config/flavours/templates/"
        return 1
    fi
}


# Apply GTK theme from theme config
apply_theme_gtk() {
    if [[ ! -f "$THEME_CONFIG" ]]; then
        log_info "No GTK theme config found"
        return 0
    fi

    if ! command -v gsettings &>/dev/null; then
        log_warning "gsettings not found - skipping GTK theme"
        return 0
    fi

    # Read GTK theme details from theme config
    local gtk_theme=$(jq -r ".gtk.theme // empty" "$THEME_CONFIG" 2>/dev/null)
    local icon_theme=$(jq -r ".gtk.icons // empty" "$THEME_CONFIG" 2>/dev/null)

    if [[ -z "$gtk_theme" ]]; then
        log_info "No GTK theme defined"
        return 0
    fi

    log_info "Applying GTK theme..."

    # Check if installed
    if [[ ! -d "$HOME/.themes/$gtk_theme" ]]; then
        log_warning "  GTK theme not installed: $gtk_theme"
        log_info "  Install with: dotfiles theme install-gtk"
        return 0
    fi

    # Apply GTK theme
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"
    log_success "  ✓ GTK: $gtk_theme"

    # Apply icon theme if available
    if [[ -n "$icon_theme" ]] && [[ -d "$HOME/.local/share/icons/$icon_theme" ]]; then
        gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
        log_success "  ✓ Icons: $icon_theme"
    fi

    # Apply cursor theme if available
    local cursor_theme=$(jq -r ".gtk.cursor // empty" "$THEME_CONFIG" 2>/dev/null)
    local cursor_size=$(jq -r ".gtk.cursor_size // 24" "$THEME_CONFIG" 2>/dev/null)

    if [[ -n "$cursor_theme" ]]; then
        # Check if cursor theme is installed
        if [[ -d "$HOME/.local/share/icons/$cursor_theme/cursors" ]] || [[ -d "/usr/share/icons/$cursor_theme/cursors" ]]; then
            gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme"
            gsettings set org.gnome.desktop.interface cursor-size "$cursor_size"
            log_success "  ✓ Cursor: $cursor_theme (size: $cursor_size)"

            # Also set for Hyprland
            export XCURSOR_THEME="$cursor_theme"
            export XCURSOR_SIZE="$cursor_size"
        else
            log_warning "  ⊘ Cursor theme not installed: $cursor_theme"
        fi
    fi

    # Set color scheme based on theme name
    if [[ "$gtk_theme" =~ -[Dd]ark || "$gtk_theme" =~ -dark ]]; then
        gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    else
        gsettings set org.gnome.desktop.interface color-scheme "prefer-light"
    fi

    return 0
}

# Select and apply theme interactively
theme_select() {
    # Ensure flavours is available
    local flavours_cmd="flavours"
    if ! command -v flavours &>/dev/null; then
        if [[ -x "$HOME/.cargo/bin/flavours" ]]; then
            flavours_cmd="$HOME/.cargo/bin/flavours"
        else
            log_error "Flavours not found"
            log_info "Run: dotfiles install"
            return 1
        fi
    fi

    log_section "Select Theme"

    # Get list of available themes
    local themes_output=$("$flavours_cmd" list 2>&1)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get theme list"
        echo "$themes_output"
        return 1
    fi

    # Convert space-separated output to array (one theme per line for gum)
    local themes=()
    read -ra themes <<< "$themes_output"

    if [[ ${#themes[@]} -eq 0 ]]; then
        log_error "No themes found"
        log_info "Run: flavours update schemes"
        return 1
    fi

    # Get current theme
    local current_theme=$("$flavours_cmd" current 2>/dev/null || echo "")

    # Show theme selection
    local selected=""
    if [[ -n "$current_theme" ]]; then
        # Try to preselect current theme
        selected=$(printf '%s\n' "${themes[@]}" | filter_search "Select theme (current: $current_theme)" --limit 1)
    else
        selected=$(printf '%s\n' "${themes[@]}" | filter_search "Select theme" --limit 1)
    fi

    # Check if user cancelled
    if [[ -z "$selected" ]]; then
        return 0
    fi

    # Apply the selected theme (suppress output)
    if "$flavours_cmd" apply "$selected" &>/dev/null; then
        # Update the default scheme to the selected one
        # Find the scheme file using flavours info to get the exact path
        local scheme_info=$("$flavours_cmd" info "$selected" 2>&1 | head -1)
        local source_scheme=""

        # Extract path from output like: "Ashes (ashes) @ /path/to/ashes.yaml"
        if [[ "$scheme_info" =~ @[[:space:]](.+\.ya?ml) ]]; then
            source_scheme="${BASH_REMATCH[1]}"
        fi

        if [[ -n "$source_scheme" && -f "$source_scheme" ]]; then
            # Copy to stow directory using scheme name (not hardcoded "default")
            local schemes_dir="$DOTFILES_DIR/stow/flavours/.config/flavours/schemes"
            local stow_scheme_dir="$schemes_dir/$selected"
            local stow_scheme="$stow_scheme_dir/$selected.yaml"
            mkdir -p "$stow_scheme_dir"
            cp "$source_scheme" "$stow_scheme"
            
            # Also copy to default location (convention for active scheme)
            local default_scheme="$schemes_dir/default/default.yaml"
            mkdir -p "$(dirname "$default_scheme")"
            cp "$source_scheme" "$default_scheme"

            # Also copy to active config (if stowed) - use scheme name
            local config_scheme_dir="$HOME/.config/flavours/schemes/$selected"
            if [[ -d "$HOME/.config/flavours/schemes" ]]; then
                mkdir -p "$config_scheme_dir"
                cp "$source_scheme" "$config_scheme_dir/$selected.yaml"
            fi
        fi

        log_success "Theme '$selected' applied!"
        return 0
    else
        echo
        log_error "Failed to apply theme '$selected'"
        return 1
    fi
}

# Apply theme (main entry point)
theme_apply() {
    log_section "Applying Theme"

    # Apply flavours theme (all files are auto-generated)
    apply_flavours_theme
    echo

    # Apply GTK theme
    apply_theme_gtk
    echo

    log_success "Theme applied!"
    echo
    log_info "Restart applications to see changes"

    return 0
}

# Find scheme file in dotfiles (checks current scheme name first, then default location)
get_scheme_file() {
    local schemes_dir="$DOTFILES_DIR/stow/flavours/.config/flavours/schemes"
    
    # Get current scheme from flavours
    local current_scheme="none"
    if command -v flavours &>/dev/null || [[ -x "$HOME/.cargo/bin/flavours" ]]; then
        local flavours_cmd="flavours"
        [[ ! -x "$(command -v flavours)" ]] && flavours_cmd="$HOME/.cargo/bin/flavours"
        current_scheme=$("$flavours_cmd" current 2>/dev/null || echo "none")
    fi
    
    # Return scheme file path if it exists
    if [[ "$current_scheme" != "none" ]] && [[ -n "$current_scheme" ]]; then
        local scheme_path="$schemes_dir/$current_scheme/$current_scheme.yaml"
        if [[ -f "$scheme_path" ]]; then
            echo "$scheme_path"
            return 0
        fi
    fi
    
    return 1
}

# Show theme status
theme_status() {
    log_section "Theme Status"

    local current_scheme="none"
    if command -v flavours &>/dev/null || [[ -x "$HOME/.cargo/bin/flavours" ]]; then
        local flavours_cmd="flavours"
        [[ ! -x "$(command -v flavours)" ]] && flavours_cmd="$HOME/.cargo/bin/flavours"
        current_scheme=$("$flavours_cmd" current 2>/dev/null || echo "none")
    fi

    # Get scheme file from flavours
    local scheme_file=""
    if scheme_file=$(get_scheme_file); then
        # File exists - check if it's valid
        if grep -q "^base00:" "$scheme_file"; then
            theme_show_current
        else
            show_info "Flavours scheme" "$current_scheme"
            log_warning "Scheme file found but invalid: $scheme_file"
        fi
    else
        if [[ "$current_scheme" != "none" ]]; then
            show_info "Flavours scheme" "$current_scheme"
            log_info "No scheme file in dotfiles"
        else
            show_info "Flavours scheme" "not applied"
        fi
    fi
    echo
    # Show GTK theme info if available
    if command -v gsettings &>/dev/null; then
        local gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
        local icon_theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
        local cursor_theme=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
        local cursor_size=$(gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null)

        if [[ -n "$gtk_theme" ]]; then
            show_info "GTK theme" "$gtk_theme"
        fi
        if [[ -n "$icon_theme" ]]; then
            show_info "Icon theme" "$icon_theme"
        fi
        if [[ -n "$cursor_theme" ]]; then
            show_info "Cursor theme" "$cursor_theme (size: $cursor_size)"
        fi
    fi

    # Show actionable info
    if [[ "$current_scheme_lower" != "$dotfiles_scheme_lower" ]] && [[ "$current_scheme" != "none" ]] && [[ "$dotfiles_scheme" != "none" ]]; then
        log_warning "Theme needs sync"
    fi
}

# Install GTK theme from theme config
theme_install_gtk() {
    if [[ ! -f "$THEME_CONFIG" ]]; then
        graceful_error "Theme config not found: $THEME_CONFIG"
        return 1
    fi

    local name=$(jq -r ".gtk.name // empty" "$THEME_CONFIG")
    local gtk_repo=$(jq -r ".gtk.install.gtk_repo // empty" "$THEME_CONFIG")
    local gtk_cmd=$(jq -r ".gtk.install.gtk_cmd // empty" "$THEME_CONFIG")
    local icons_repo=$(jq -r ".gtk.install.icons_repo // empty" "$THEME_CONFIG")
    local icons_cmd=$(jq -r ".gtk.install.icons_cmd // empty" "$THEME_CONFIG")

    if [[ -z "$gtk_repo" ]]; then
        graceful_error "No GTK theme install info in gtk.json"
        return 1
    fi

    log_section "Installing GTK Theme"

    if [[ -n "$name" ]]; then
        show_info "Theme" "$name"
        echo
    fi

    local temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN

    local failed=0

    # Install GTK theme
    log_info "Installing GTK theme from repository..."
    local repo_name=$(basename "$gtk_repo" .git)
    echo

    if git clone --depth=1 --progress "$gtk_repo" "$temp_dir/$repo_name"; then
        echo
        cd "$temp_dir/$repo_name"
        log_info "Running GTK theme install script..."
        if eval "$gtk_cmd"; then
            echo
            log_success "GTK theme installed"
        else
            echo
            log_error "GTK theme install failed"
            ((failed++))
        fi
        cd - >/dev/null
    else
        echo
        log_error "Failed to clone GTK repository"
        ((failed++))
    fi

    # Install icon theme
    if [[ -n "$icons_repo" ]]; then
        echo
        log_info "Installing icon theme from repository..."
        local repo_name=$(basename "$icons_repo" .git)
        echo

        if git clone --depth=1 --progress "$icons_repo" "$temp_dir/$repo_name"; then
            echo
            cd "$temp_dir/$repo_name"
            log_info "Running icon theme install script..."
            if eval "$icons_cmd"; then
                echo
            else
                echo
                log_error "Icon theme install failed"
                ((failed++))
            fi
            cd - &>/dev/null
        else
            log_error "  ✗ Failed to clone icon repo"
            ((failed++))
        fi
    fi

    echo
    if [[ $failed -eq 0 ]]; then
        return 0
    else
        log_error "Installation failed with $failed error(s)"
        return 1
    fi
}

# Theme management menu
theme_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"

    while true; do
        clear_screen "Themes"
        theme_show_current
        echo

        local action=$(choose_option \
            "Select theme" \
            "Install GTK theme" \
            "Show details" \
            "Back")

        [[ -z "$action" ]] && return

        case "$action" in
            "Select theme")
                run_operation "" theme_select
                ;;
            "Install GTK theme")
                run_operation "" theme_install_gtk
                ;;
            "Show details")
                run_operation "" theme_status
                ;;
            "Back")
                return
                ;;
        esac
    done
}
