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
    
    local color="dark"
    local variant="standard"
    local dest="$HOME/.themes"
    local install_args=()
    
    if command -v gum &>/dev/null; then
        color=$(printf "dark\nlight\n" | gum choose --no-show-help --header "")
        [[ -z "$color" ]] && return 0
        
        variant=$(printf "standard\nsolid\n" | gum choose --no-show-help --header "")
        [[ -z "$variant" ]] && return 0
    else
        echo
        echo "Color variant:"
        echo "  1) dark"
        echo "  2) light"
        read -p "> " color_choice
        color_choice="${color_choice:-1}"
        [[ "$color_choice" == "2" ]] && color="light"
        
        echo
        echo "Variant:"
        echo "  1) standard"
        echo "  2) solid"
        read -p "> " variant_choice
        variant_choice="${variant_choice:-1}"
        [[ "$variant_choice" == "2" ]] && variant="solid"
    fi
    
    install_args+=("--dest" "$dest")
    
    if [[ "$color" == "light" ]]; then
        install_args+=("--color" "light")
    fi
    
    if [[ "$variant" == "solid" ]]; then
        install_args+=("--solid")
    fi
    
    echo
    (
        cd "$theme_path" || exit 1
        log_info "Running: ./install.sh ${install_args[*]}"
        ./install.sh "${install_args[@]}"
    )
    
    if [[ $? -eq 0 ]]; then
        echo
        log_success "Installed: $theme_name"
        
        if command -v gsettings &>/dev/null; then
            local full_theme_name="${theme_name}-${color^}"
            gsettings set org.gnome.desktop.interface gtk-theme "$full_theme_name"
            log_info "Active GTK theme: $full_theme_name"
        fi
        
        echo
        read -n 1 -s -r -p "Press any key to continue..."
        return 0
    else
        echo
        log_error "Installation failed"
        echo
        read -n 1 -s -r -p "Press any key to continue..."
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
            read -n 1 -s -r -p "Press any key to continue..."
            return 1
        fi
        echo
        read -n 1 -s -r -p "Press any key to continue..."
        return 0
    fi
    
    log_info "Current theme: $current_gtk"
    echo
    
    local base_name=$(echo "$current_gtk" | sed -E 's/-(Dark|Light|dark|light)$//')
    local theme_path="$THEMES_DIR/${base_name}"
    
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
    else
        rm -rf "$HOME/.themes/${current_gtk}" "$HOME/.themes/${base_name}"*
    fi
    
    echo
    log_success "Uninstalled: $current_gtk"
    echo
    read -n 1 -s -r -p "Press any key to continue..."
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
                    return 1
                fi
                
                if command -v gum &>/dev/null; then
                    theme_name=$(printf '%s\n' "${themes[@]}" | gum choose --no-show-help --header "")
                    [[ -z "$theme_name" ]] && return 0
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
            log_info "Usage: ./lib/themes.sh [command]"
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

