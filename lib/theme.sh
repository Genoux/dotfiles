#!/bin/bash
# Matugen-era theme status and GTK theme tools

DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"

if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    DOTFILES_HELPERS_LOADED=true
fi

MATUGEN_CONFIG="$HOME/.config/matugen/config.toml"
CURRENT_WALLPAPER="$HOME/.config/hypr/wallpapers/current/current_wallpaper.jpg"

declare -a MATUGEN_OUTPUTS=(
    "$HOME/.config/kitty/matugen-theme.conf"
    "$HOME/.config/btop/themes/matugen.theme"
    "$HOME/.config/quickshell/Colors.qml"
    "$HOME/.config/ags/styles/abstracts/_theme.scss"
    "$HOME/.config/starship.toml"
    "$HOME/.config/zsh/highlight-colors.zsh"
    "$HOME/.config/matugen/dotfiles-gum.env"
    "$HOME/.cursor/extensions/matugen.material-you-1.0.0/package.json"
    "$HOME/.cursor/extensions/matugen.material-you-1.0.0/themes/matugen-color-theme.json"
)

declare -a MATUGEN_STOW_SYMLINK_OUTPUTS=(
    "$HOME/.config/quickshell/Colors.qml"
    "$HOME/.config/ags/styles/abstracts/_theme.scss"
    "$HOME/.config/btop/themes/matugen.theme"
)

declare -a MATUGEN_STOW_STYLE_LINKS=(
    "$DOTFILES_DIR/stow/ags/.config/ags/styles/abstracts/_theme.scss|$HOME/.config/ags/styles/abstracts/_theme.scss"
)

matugen_wallpaper_scheme() {
    local wallpaper="$1"
    local scheme="scheme-tonal-spot"

    if command -v magick &>/dev/null; then
        local saturation
        saturation=$(magick "$wallpaper" -colorspace HSL -channel g \
            -separate -format "%[fx:mean]" info: 2>/dev/null || echo "1")
        if awk -v s="$saturation" 'BEGIN { exit !(s < 0.05) }'; then
            scheme="scheme-monochrome"
        fi
    fi

    printf '%s' "$scheme"
}

matugen_migrate_output_symlinks() {
    local path target

    for path in "${MATUGEN_STOW_SYMLINK_OUTPUTS[@]}"; do
        [[ -L "$path" ]] || continue
        target=$(readlink "$path" 2>/dev/null || true)
        [[ "$target" == *"dotfiles/stow/"* ]] || continue
        rm "$path"
        log_info "Removed stow symlink for matugen output: ${path/#$HOME/~}"
    done
}

# AGS tokens.scss lives in stow; sass resolves @use relative to that path.
matugen_sync_stow_style_links() {
    local entry stow_path live_path stow_dir

    for entry in "${MATUGEN_STOW_STYLE_LINKS[@]}"; do
        stow_path="${entry%%|*}"
        live_path="${entry##*|}"
        [[ -f "$live_path" ]] || continue
        stow_dir=$(dirname "$stow_path")
        mkdir -p "$stow_dir"
        ln -sf "$live_path" "$stow_path"
    done
}

matugen_generate_from_wallpaper() {
    local wallpaper="${1:-$CURRENT_WALLPAPER}"

    matugen_migrate_output_symlinks

    if ! command -v matugen &>/dev/null; then
        log_warning "matugen not installed — skipping theme generation"
        return 1
    fi

    # On a fresh machine there is no current wallpaper yet, so seed one from the
    # shipped saves/ — otherwise themes (kitty, starship, btop, ...) never get
    # generated on install.
    if [[ ! -f "$wallpaper" ]]; then
        local seed
        seed=$(find "$HOME/.config/hypr/wallpapers/saves" -maxdepth 1 -xtype f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            2>/dev/null | sort | head -1)
        if [[ -n "$seed" ]]; then
            mkdir -p "$(dirname "$CURRENT_WALLPAPER")"
            cp "$seed" "$CURRENT_WALLPAPER"
            wallpaper="$CURRENT_WALLPAPER"
            log_info "Seeded initial wallpaper from saves: $(basename "$seed")"
        fi
    fi

    if [[ ! -f "$wallpaper" ]]; then
        log_warning "No wallpaper at ${wallpaper/#$HOME/~} — skipping matugen"
        return 1
    fi

    local scheme
    scheme=$(matugen_wallpaper_scheme "$wallpaper")
    # ponytail: removed --prefer and --source-color-index (not in matugen 3.1.0)
    if matugen image -t "$scheme" "$wallpaper"; then
        matugen_sync_stow_style_links
        return 0
    fi
    return 1
}

matugen_ensure_outputs() {
    local output_path

    matugen_migrate_output_symlinks

    for output_path in "${MATUGEN_OUTPUTS[@]}"; do
        if [[ ! -f "$output_path" ]] || [[ -L "$output_path" ]]; then
            log_info "Generating missing matugen theme outputs..."
            if matugen_generate_from_wallpaper; then
                return 0
            fi
            log_warning "Matugen generation skipped or failed"
            return 1
        fi
    done

    matugen_sync_stow_style_links
}

get_current_gtk_theme() {
    if command -v gsettings &>/dev/null; then
        gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'"
    else
        echo "unknown"
    fi
}

show_theme_name() {
    if [[ -f "$CURRENT_WALLPAPER" ]]; then
        show_info "Theme source" "$(basename "$CURRENT_WALLPAPER")"
    else
        show_info "Theme source" "no current wallpaper"
    fi

    local gtk_theme
    gtk_theme=$(get_current_gtk_theme)
    if [[ -n "$gtk_theme" && "$gtk_theme" != "unknown" ]]; then
        show_info "GTK theme" "$gtk_theme"
    fi
}

theme_show_current() {
    show_theme_name
    echo
}

_show_file_status() {
    local label="$1"
    local file_path="$2"

    if [[ -f "$file_path" ]]; then
        show_info "$label" "present"
    else
        show_info "$label" "missing"
    fi
}

theme_status() {
    local skip_title="${1:-}"
    [[ "$skip_title" != "--skip-title" ]] && log_section "Theme Status"

    if command -v matugen &>/dev/null; then
        show_info "Matugen" "installed"
    else
        show_info "Matugen" "not installed"
    fi

    _show_file_status "Matugen config" "$MATUGEN_CONFIG"
    _show_file_status "Current wallpaper" "$CURRENT_WALLPAPER"
    echo

    log_info "Generated outputs"
    for output_path in "${MATUGEN_OUTPUTS[@]}"; do
        if [[ -f "$output_path" ]]; then
            printf "  %s %s\n" "$(status_ok)" "${output_path/#$HOME/~}"
        else
            printf "  %s %s\n" "$(status_warning)" "${output_path/#$HOME/~}"
        fi
    done

    echo
    if command -v gsettings &>/dev/null; then
        local gtk_theme
        local icon_theme
        local cursor_theme
        local cursor_size

        gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
        icon_theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
        cursor_theme=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
        cursor_size=$(gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null)

        [[ -n "$gtk_theme" ]] && show_info "GTK theme" "$gtk_theme"
        [[ -n "$icon_theme" ]] && show_info "Icon theme" "$icon_theme"
        [[ -n "$cursor_theme" ]] && show_info "Cursor theme" "$cursor_theme (size: $cursor_size)"
    fi
}

theme_install_gtk() {
    bash "$DOTFILES_DIR/lib/gtk.sh" install
}

theme_uninstall_gtk() {
    bash "$DOTFILES_DIR/lib/gtk.sh" uninstall
}

gtk_theme_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"

    while true; do
        clear_screen "GTK Themes"

        local current_gtk
        current_gtk=$(get_current_gtk_theme)
        show_info "Active" "$current_gtk"
        echo

        local action
        action=$(choose_option \
            "Install theme" \
            "Uninstall current" \
            "Back")

        [[ -z "$action" ]] && return

        case "$action" in
            "Install theme")
                clear_screen "GTK Themes"
                theme_install_gtk
                ;;
            "Uninstall current")
                clear_screen "GTK Themes"
                theme_uninstall_gtk
                ;;
            "Back")
                return
                ;;
        esac
    done
}

theme_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"

    while true; do
        clear_screen "Themes"
        theme_show_current

        local action
        action=$(choose_option \
            "Show status" \
            "GTK themes" \
            "Back")

        [[ -z "$action" ]] && return

        case "$action" in
            "Show status")
                run_operation "" theme_status
                ;;
            "GTK themes")
                gtk_theme_menu
                ;;
            "Back")
                return
                ;;
        esac
    done
}
