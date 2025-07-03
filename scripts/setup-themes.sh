#!/bin/bash

# setup-themes.sh - WhiteSur theme installation
# Internal worker script - called by dotfiles.sh to install WhiteSur themes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Simple flag parsing
FORCE=false
QUIET=false

for arg in "$@"; do
    case $arg in
        --force) FORCE=true ;;
        --quiet) QUIET=true ;;
    esac
done

# Check theme installation status
check_theme_status() {
    local theme_type="$1"
    
    case "$theme_type" in
        "gtk")
            [[ -d "$HOME/.themes/WhiteSur-Light" ]] && echo "installed" || echo "missing"
            ;;
        "icons")
            ([[ -d "$HOME/.icons/WhiteSur" ]] || [[ -d "$HOME/.local/share/icons/WhiteSur" ]]) && echo "installed" || echo "missing"
            ;;
        "cursors")
            ([[ -d "$HOME/.icons/WhiteSur-cursors" ]] || [[ -d "$HOME/.local/share/icons/WhiteSur-cursors" ]]) && echo "installed" || echo "missing"
            ;;
    esac
}

# Install WhiteSur GTK theme
install_gtk_theme() {
    local status=$(check_theme_status "gtk")
    
    if [[ "$status" == "installed" && "$FORCE" != true ]]; then
        [[ "$QUIET" != true ]] && log_success "WhiteSur GTK theme already installed"
        return 0
    fi
    
    if [[ "$status" == "installed" && "$FORCE" == true ]]; then
        [[ "$QUIET" != true ]] && log_info "Reinstalling GTK theme..."
        rm -rf "$HOME/.themes"/WhiteSur*
    fi
    
    [[ "$QUIET" != true ]] && log_step "Installing WhiteSur GTK theme..."
    
    local temp_dir=$(mktemp -d)
    if clone_repo "https://github.com/vinceliuice/WhiteSur-gtk-theme.git" "$temp_dir/WhiteSur-gtk-theme"; then
        cd "$temp_dir/WhiteSur-gtk-theme"
        if ./install.sh; then
            [[ "$QUIET" != true ]] && log_success "WhiteSur GTK theme installed"
        else
            log_error "Failed to install WhiteSur GTK theme"
            return 1
        fi
    else
        return 1
    fi
    
    rm -rf "$temp_dir"
    return 0
}

# Install WhiteSur icon theme
install_icon_theme() {
    local status=$(check_theme_status "icons")
    
    if [[ "$status" == "installed" && "$FORCE" != true ]]; then
        [[ "$QUIET" != true ]] && log_success "WhiteSur icon theme already installed"
        return 0
    fi
    
    if [[ "$status" == "installed" && "$FORCE" == true ]]; then
        [[ "$QUIET" != true ]] && log_info "Reinstalling icon theme..."
        rm -rf "$HOME/.icons"/WhiteSur* "$HOME/.local/share/icons"/WhiteSur*
    fi
    
    [[ "$QUIET" != true ]] && log_step "Installing WhiteSur icon theme..."
    
    local temp_dir=$(mktemp -d)
    if clone_repo "https://github.com/vinceliuice/WhiteSur-icon-theme.git" "$temp_dir/WhiteSur-icon-theme"; then
        cd "$temp_dir/WhiteSur-icon-theme"
        if ./install.sh -a; then
            [[ "$QUIET" != true ]] && log_success "WhiteSur icon theme installed"
        else
            log_error "Failed to install WhiteSur icon theme"
            return 1
        fi
    else
        return 1
    fi
    
    rm -rf "$temp_dir"
    return 0
}

# Install WhiteSur cursor theme
install_cursor_theme() {
    local status=$(check_theme_status "cursors")
    
    if [[ "$status" == "installed" && "$FORCE" != true ]]; then
        [[ "$QUIET" != true ]] && log_success "WhiteSur cursor theme already installed"
        return 0
    fi
    
    if [[ "$status" == "installed" && "$FORCE" == true ]]; then
        [[ "$QUIET" != true ]] && log_info "Reinstalling cursor theme..."
        rm -rf "$HOME/.icons"/WhiteSur-cursors* "$HOME/.local/share/icons"/WhiteSur-cursors*
    fi
    
    [[ "$QUIET" != true ]] && log_step "Installing WhiteSur cursor theme..."
    
    local temp_dir=$(mktemp -d)
    if clone_repo "https://github.com/vinceliuice/WhiteSur-cursors.git" "$temp_dir/WhiteSur-cursors"; then
        cd "$temp_dir/WhiteSur-cursors"
        if ./install.sh; then
            [[ "$QUIET" != true ]] && log_success "WhiteSur cursor theme installed"
        else
            log_error "Failed to install WhiteSur cursor theme"
            return 1
        fi
    else
        return 1
    fi
    
    rm -rf "$temp_dir"
    return 0
}

# Main execution - install all themes
if [[ "$QUIET" != true ]]; then
    log_section "Installing WhiteSur Themes"
    start_timer
fi

failed=0

# Install GTK theme
install_gtk_theme || ((failed++))

# Install icon theme
install_icon_theme || ((failed++))

# Install cursor theme
install_cursor_theme || ((failed++))

if [[ "$QUIET" != true ]]; then
    echo
    if [[ $failed -eq 0 ]]; then
        log_success "All themes installed successfully! ($(stop_timer))"
        echo
        echo -e "${YELLOW}💡 Next steps:${NC}"
        echo "  • Restart your desktop environment"
        echo "  • Configure themes in your settings"
    else
        log_warning "$failed theme(s) failed to install"
    fi
fi

exit $failed 