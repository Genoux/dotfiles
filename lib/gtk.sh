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

cursor_theme_has_cursors() {
    local cursor_theme="$1"
    local cursor_dir

    for cursor_dir in \
        "$HOME/.local/share/icons/$cursor_theme/cursors" \
        "$HOME/.icons/$cursor_theme/cursors" \
        "/usr/share/icons/$cursor_theme/cursors"; do
        [[ -d "$cursor_dir" ]] && return 0
    done

    return 1
}

select_cursor_theme() {
    local base_theme_name="$1"
    local color="$2"
    local current_cursor=""
    local candidate

    if command -v gsettings &>/dev/null; then
        current_cursor=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
    fi

    for candidate in \
        "${base_theme_name}-${color}" \
        "${base_theme_name}-${color^}" \
        "$base_theme_name" \
        "$current_cursor" \
        "default"; do
        [[ -n "$candidate" ]] || continue
        if cursor_theme_has_cursors "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    printf '%s\n' "default"
}

read_hypr_cursor_size() {
    local cursor_lua="$HOME/.config/hypr/cursor.lua"
    local size

    if [[ -f "$cursor_lua" ]]; then
        size=$(rg -o 'size\s*=\s*"([0-9]+)"' "$cursor_lua" -r '$1' --no-line-number 2>/dev/null | head -1)
    fi

    if [[ "$size" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$size"
        return 0
    fi

    printf '%s\n' "24"
}

write_hypr_cursor_config() {
    local cursor_theme="$1"
    local generated_dir="$HOME/.config/hypr/generated"
    local generated_file="$generated_dir/cursor.lua"

    mkdir -p "$generated_dir"
    printf 'return {\n  theme = "%s",\n}\n' "$cursor_theme" > "$generated_file"
}

find_live_hyprland_signature() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    local instance_dir
    local signature

    for instance_dir in "$runtime_dir"/hypr/*; do
        [[ -S "$instance_dir/.socket.sock" ]] || continue
        signature="$(basename "$instance_dir")"

        if HYPRLAND_INSTANCE_SIGNATURE="$signature" hyprctl version >/dev/null 2>&1; then
            printf '%s\n' "$signature"
            return 0
        fi
    done

    return 1
}

apply_cursor_theme() {
    local cursor_theme="$1"
    local cursor_size
    cursor_size=$(read_hypr_cursor_size)
    local cursor_path="$HOME/.local/share/icons:$HOME/.icons:/usr/share/icons:/usr/share/pixmaps"

    write_hypr_cursor_config "$cursor_theme"

    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme"
    fi

    if command -v systemctl &>/dev/null; then
        systemctl --user set-environment \
            XCURSOR_THEME="$cursor_theme" \
            XCURSOR_PATH="$cursor_path" 2>/dev/null || true
    fi

    local signature
    if signature=$(find_live_hyprland_signature); then
        HYPRLAND_INSTANCE_SIGNATURE="$signature" hyprctl setcursor "$cursor_theme" "$cursor_size" >/dev/null 2>&1 || true
    fi
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
    
    install_args+=("--dest" "$dest" "-l")
    
    if [[ "$color" == "light" ]]; then
        install_args+=("--color" "light")
    fi
    
    if [[ "$variant" == "solid" ]]; then
        install_args+=("--solid")
    fi
    
    echo
    log_info "Running: ./install.sh ${install_args[*]}"
    echo
    
    # Run installation and capture output
    local install_output
    local install_exit
    (
        cd "$theme_path" || exit 1
        ./install.sh "${install_args[@]}" 2>&1
    )
    install_exit=$?
    
    if [[ $install_exit -eq 0 ]]; then
        echo
        log_success "Installed: $theme_name"
        
        if command -v gsettings &>/dev/null; then
            # Strip common suffixes to get base theme name
            local base_theme_name="${theme_name%-gtk-theme}"
            base_theme_name="${base_theme_name%-theme}"
            
            # Construct the actual installed theme name
            local full_theme_name="${base_theme_name}-${color^}"
            if [[ "$variant" == "solid" ]]; then
                full_theme_name="${base_theme_name}-${color^}-solid"
            fi
            
            gsettings set org.gnome.desktop.interface gtk-theme "$full_theme_name"
            log_info "Active GTK theme: $full_theme_name"

            local cursor_theme
            cursor_theme=$(select_cursor_theme "$base_theme_name" "$color")
            apply_cursor_theme "$cursor_theme"
            log_info "Active cursor theme: $cursor_theme (size from hypr: $(read_hypr_cursor_size))"
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

