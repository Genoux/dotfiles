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
    # Scheme is also managed via stow (stow/flavours/.config/flavours/schemes/default/default.yaml)
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

# Show theme status
theme_status() {
    log_section "Theme Status"

    show_info "Theme" "default"

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

    echo
    log_info "All theme files are managed by flavours"
    log_info "See: stow/flavours/.config/flavours/config.toml"

    if command -v flavours &>/dev/null; then
        local current_scheme=$(flavours current 2>/dev/null || echo "none")
        show_info "Current flavours scheme" "$current_scheme"
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
                log_success "Icon theme installed"
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
        log_success "GTK theme installed successfully!"
        echo
        log_info "Apply with: dotfiles theme apply"
        return 0
    else
        log_error "Installation failed with $failed error(s)"
        return 1
    fi
}
