#!/bin/bash
# GTK theme installation script

DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
THEMES_DIR="$DOTFILES_DIR/themes"

# Always source helpers to ensure functions are available
source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || {
    echo "Error: Could not load helpers from $DOTFILES_DIR/install/helpers/all.sh"
    exit 1
}

list_themes() {
    local themes=()
    
    for theme_path in "$THEMES_DIR"/*; do
        [[ -d "$theme_path" ]] || continue
        [[ -x "$theme_path/install.sh" ]] || continue
        
        local theme_name=$(basename "$theme_path")
        themes+=("$theme_name")
    done
    
    printf '%s\n' "${themes[@]}"
}

install_theme() {
    local theme_name="$1"
    local theme_path="$THEMES_DIR/${theme_name}"
    
    if [[ ! -d "$theme_path" ]]; then
        log_error "Theme not found: $theme_name"
        return 1
    fi
    
    if [[ ! -x "$theme_path/install.sh" ]]; then
        log_error "No executable install.sh: $theme_path"
        return 1
    fi
    
    log_section "Installing GTK Theme: $theme_name"
    
    local dest="$HOME/.themes"
    
    # Try simple command first: -l (libadwaita) -c dark (color)
    # For Workspace theme, defaults are already workspace scheme and dark color
    log_info "Using default config: dark + libadwaita"
    
    echo
    log_info "Running: ./install.sh -l -c dark"
    echo
    
    # Run installation with simple command first
    local install_exit
    (
        cd "$theme_path" || exit 1
        ./install.sh -l -c dark 2>&1
    )
    install_exit=$?
    
    # If simple command fails, try with explicit dest and tweaks
    if [[ $install_exit -ne 0 ]]; then
        log_warning "Simple install failed, trying with explicit arguments..."
        echo
        log_info "Running: ./install.sh --dest $dest --tweaks workspace --color dark -l system"
        echo
        
        (
            cd "$theme_path" || exit 1
            ./install.sh --dest "$dest" --tweaks workspace --color dark -l system 2>&1
        )
        install_exit=$?
    fi
    
    echo
    
    if [[ $install_exit -eq 0 ]]; then
        # Determine installed theme name
        local base_theme_name="${theme_name%-gtk-theme}"
        base_theme_name="${base_theme_name%-theme}"
        
        # Try different theme name patterns
        local full_theme_name=""
        local theme_dir=""
        
        # For Workspace theme: Workspace-Dark-Workspace
        if [[ -d "$dest/${base_theme_name}-Dark-Workspace" ]]; then
            full_theme_name="${base_theme_name}-Dark-Workspace"
            theme_dir="$dest/${full_theme_name}"
        # For other themes: might be ThemeName-Dark or just ThemeName-Dark
        elif [[ -d "$dest/${base_theme_name}-Dark" ]]; then
            full_theme_name="${base_theme_name}-Dark"
            theme_dir="$dest/${full_theme_name}"
        # Fallback: check for any directory starting with base name
        else
            theme_dir=$(find "$dest" -maxdepth 1 -type d -name "${base_theme_name}*" -print -quit 2>/dev/null)
            if [[ -n "$theme_dir" ]]; then
                full_theme_name=$(basename "$theme_dir")
            fi
        fi
        
        if [[ -z "$theme_dir" ]] || [[ ! -d "$theme_dir" ]]; then
            log_error "Installation completed but theme directory not found in $dest"
            log_info "Expected patterns: ${base_theme_name}-Dark-Workspace or ${base_theme_name}-Dark"
            echo
            if [[ "${FULL_INSTALL:-false}" != "true" ]]; then
                read -n 1 -s -r -p "Press any key to continue..."
            fi
            return 1
        fi
        
        log_success "Installed: $theme_name"
        log_info "Theme directory: $theme_dir"
        
        if command -v gsettings &>/dev/null && [[ -n "$full_theme_name" ]]; then
            if gsettings set org.gnome.desktop.interface gtk-theme "$full_theme_name" 2>/dev/null; then
                log_info "Active GTK theme: $full_theme_name"
            else
                log_warning "Could not set GTK theme via gsettings"
            fi
        fi
        
        echo
        # Skip prompt during full install
        if [[ "${FULL_INSTALL:-false}" != "true" ]]; then
            read -n 1 -s -r -p "Press any key to continue..."
        fi
        return 0
    else
        log_error "Installation failed (exit code: $install_exit)"
        echo
        # Skip prompt during full install
        if [[ "${FULL_INSTALL:-false}" != "true" ]]; then
            read -n 1 -s -r -p "Press any key to continue..."
        fi
        return 1
    fi
}

uninstall_current_theme() {
    log_section "Uninstalling Current Theme"
    
    local current_gtk=""
    if command -v gsettings &>/dev/null; then
        current_gtk=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
    fi
    
    if [[ -z "$current_gtk" ]] || [[ "$current_gtk" == "unknown" ]] || [[ "$current_gtk" == "Default" ]]; then
        log_warning "No custom GTK theme active, checking for installed themes..."
        
        local available_themes=($(list_themes))
        if [[ ${#available_themes[@]} -gt 0 ]]; then
            log_info "Found installed themes, attempting to uninstall all variants"
            for theme in "${available_themes[@]}"; do
                local theme_path="$THEMES_DIR/${theme}"
                if [[ -x "$theme_path/uninstall.sh" ]]; then
                    (
                        cd "$theme_path" || exit 1
                        ./uninstall.sh
                    )
                elif [[ -x "$theme_path/install.sh" ]]; then
                    (
                        cd "$theme_path" || exit 1
                        ./install.sh --remove
                    )
                fi
            done
            log_success "Uninstalled all theme variants"
        else
            log_error "No themes found to uninstall"
            echo
            if [[ "${FULL_INSTALL:-false}" != "true" ]]; then
                read -n 1 -s -r -p "Press any key to continue..."
            fi
            return 1
        fi
        echo
        if [[ "${FULL_INSTALL:-false}" != "true" ]]; then
            read -n 1 -s -r -p "Press any key to continue..."
        fi
        return 0
    fi
    
    log_info "Current theme: $current_gtk"
    echo
    
    # Extract base theme name from installed theme name
    # Pattern: "Workspace-Dark-Workspace" -> "Workspace"
    # Try to match known theme directory patterns
    local theme_path=""
    local uninstalled=false
    
    # Try to find theme directory by matching base name
    # Remove variant (Dark/Light) and scheme suffixes
    local base_name=$(echo "$current_gtk" | sed -E 's/-(Dark|Light|dark|light)(-.*)?$//')
    
    # Check common theme directory name patterns
    for pattern in "${base_name}-gtk-theme" "${base_name}-theme" "${base_name}"; do
        if [[ -d "$THEMES_DIR/${pattern}" ]] && [[ -x "$THEMES_DIR/${pattern}/install.sh" ]]; then
            theme_path="$THEMES_DIR/${pattern}"
            break
        fi
    done
    
    if [[ -n "$theme_path" ]]; then
        log_info "Found theme source: $(basename "$theme_path")"
        
        if [[ -x "$theme_path/uninstall.sh" ]]; then
            (
                cd "$theme_path" || exit 1
                ./uninstall.sh
            ) && uninstalled=true
        elif [[ -x "$theme_path/install.sh" ]]; then
            (
                cd "$theme_path" || exit 1
                ./install.sh --remove
            ) && uninstalled=true
        fi
    else
        # Fallback: try to remove theme directory directly
        log_warning "Could not find theme source directory, removing installed theme files"
        if [[ -d "$HOME/.themes/${current_gtk}" ]]; then
            rm -rf "$HOME/.themes/${current_gtk}" "$HOME/.themes/${base_name}"*
            uninstalled=true
        else
            log_warning "Theme directory not found: $HOME/.themes/${current_gtk}"
        fi
    fi
    
    # Reset gsettings to default theme
    if [[ "$uninstalled" == "true" ]] && command -v gsettings &>/dev/null; then
        gsettings reset org.gnome.desktop.interface gtk-theme 2>/dev/null || \
        gsettings set org.gnome.desktop.interface gtk-theme "Adwaita" 2>/dev/null
        log_info "Reset GTK theme to default"
    fi
    
    echo
    if [[ "$uninstalled" == "true" ]]; then
        log_success "Uninstalled: $current_gtk"
    else
        log_error "Failed to uninstall theme"
    fi
    echo
    if [[ "${FULL_INSTALL:-false}" != "true" ]]; then
        read -n 1 -s -r -p "Press any key to continue..."
    fi
    
    [[ "$uninstalled" == "true" ]] && return 0 || return 1
}

show_status() {
    log_section "GTK Theme Status"
    
    if command -v gsettings &>/dev/null; then
        local gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
        local icon_theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
        local cursor_theme=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
        
        show_info "GTK theme" "$gtk_theme"
        show_info "Icon theme" "$icon_theme"
        show_info "Cursor theme" "$cursor_theme"
    else
        log_warning "gsettings not available"
    fi
    
    echo
    log_info "Available themes:"
    list_themes | sed 's/^/  - /'
}

main() {
    local action="${1:-}"
    local theme_name="${2:-}"
    
    case "$action" in
        list)
            list_themes
            ;;
        install)
            if [[ -z "$theme_name" ]]; then
                local themes=($(list_themes))
                if [[ ${#themes[@]} -eq 0 ]]; then
                    log_error "No themes found in: $THEMES_DIR"
                    if [[ ! -d "$THEMES_DIR" ]]; then
                        log_error "Themes directory does not exist: $THEMES_DIR"
                    fi
                    return 1
                fi

                # During full install, pick first theme automatically
                if [[ "${FULL_INSTALL:-false}" == "true" ]]; then
                    theme_name="${themes[0]}"
                    log_info "Auto-selecting theme: $theme_name"
                elif command -v gum &>/dev/null; then
                    # Show themes for selection - use same pattern as choose_option
                    if [[ ${#themes[@]} -gt 0 ]]; then
                        # Use gum choose with muted gray header (color 8) instead of default purple
                        theme_name=$(gum choose --no-show-help --header "Select theme to install:" --header.foreground="6" "${themes[@]}")
                        local choose_exit=$?
                        
                        if [[ $choose_exit -ne 0 ]] || [[ -z "$theme_name" ]]; then
                            # User cancelled
                            return 0
                        fi
                    else
                        log_error "Themes array is empty"
                        return 1
                    fi
                else
                    echo "Select GTK theme to install:"
                    local i=1
                    for theme in "${themes[@]}"; do
                        echo "  $i) $theme"
                        ((i++))
                    done
                    echo
                    read -p "Choice (1-${#themes[@]}, or Enter to cancel): " choice

                    if [[ -z "$choice" ]]; then
                        return 0
                    fi

                    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#themes[@]} ]]; then
                        theme_name="${themes[$((choice-1))]}"
                    else
                        log_error "Invalid choice"
                        return 1
                    fi
                fi
            fi
            install_theme "$theme_name"
            ;;
        uninstall)
            uninstall_current_theme
            ;;
        status)
            show_status
            ;;
        *)
            log_section "GTK Theme Manager"
            echo
            log_info "Usage: ./lib/gtk.sh [command]"
            echo
            echo "Commands:"
            echo "  list        List available GTK themes"
            echo "  install     Install GTK theme"
            echo "  uninstall   Uninstall current GTK theme"
            echo "  status      Show current theme status"
            echo
            show_status
            ;;
    esac
}

main "$@"

