#!/bin/bash

# Theme Manager Script
# Orchestrates both color themes and shell/UI themes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLOR_THEME_SCRIPT="$SCRIPT_DIR/color-theme.sh"
SHELL_THEME_SCRIPT="$SCRIPT_DIR/shell-theme.sh"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[THEME-MGR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if required scripts exist
check_scripts() {
    local missing=()
    
    if [[ ! -f "$COLOR_THEME_SCRIPT" ]]; then
        missing+=("color-theme.sh")
    fi
    
    if [[ ! -f "$SHELL_THEME_SCRIPT" ]]; then
        missing+=("shell-theme.sh")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing theme scripts: ${missing[*]}"
        exit 1
    fi
}

# Install full theme (both color and shell)
install_full() {
    local force_flag="$1"
    
    log "Installing complete theme setup..."
    echo
    
    # Install shell/UI theme first
    log "1/2: Installing shell theme (GTK/Icons/Cursors)..."
    if bash "$SHELL_THEME_SCRIPT" install $force_flag; then
        success "Shell theme installed"
    else
        error "Shell theme installation failed"
        return 1
    fi
    
    echo
    
    # Apply color theme
    log "2/2: Applying color theme to applications..."
    if bash "$COLOR_THEME_SCRIPT"; then
        success "Color theme applied"
    else
        error "Color theme application failed"
        return 1
    fi
    
    echo
    success "Complete theme setup finished!"
}

# Install only shell theme (GTK/Icons/Cursors)
install_shell() {
    local force_flag="$1"
    
    log "Installing shell theme only..."
    bash "$SHELL_THEME_SCRIPT" install $force_flag
}

# Install only color theme (app colors)
install_colors() {
    log "Applying color theme to applications..."
    bash "$COLOR_THEME_SCRIPT"
}

# Show combined status
show_status() {
    echo -e "${BLUE}📊 Complete Theme Status:${NC}"
    echo
    
    # Shell theme status
    echo -e "${YELLOW}Shell Theme (GTK/UI):${NC}"
    bash "$SHELL_THEME_SCRIPT" status | tail -n +3  # Skip the header
    echo
    
    # Color theme status
    echo -e "${YELLOW}Color Theme (Applications):${NC}"
    if [[ -f "$SCRIPT_DIR/base.json" ]]; then
        echo -e "  Base colors: ${GREEN}✓ Available${NC}"
        
        # Check if apps directory exists and has configs
        if [[ -d "$SCRIPT_DIR/apps" ]]; then
            local app_count=$(find "$SCRIPT_DIR/apps" -name "*.json" | wc -l)
            echo -e "  App configs: ${GREEN}✓ $app_count applications configured${NC}"
        else
            echo -e "  App configs: ${RED}✗ Apps directory missing${NC}"
        fi
    else
        echo -e "  Base colors: ${RED}✗ base.json missing${NC}"
    fi
}

# Get current system theme information
get_current_system_theme() {
    local current_gtk_theme=""
    local current_icon_theme=""
    local current_cursor_theme=""
    
    # Get current themes from gsettings if available
    if command -v gsettings &>/dev/null; then
        current_gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'" || echo "unknown")
        current_icon_theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'" || echo "unknown")
        current_cursor_theme=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'" || echo "unknown")
    fi
    
    echo "GTK:$current_gtk_theme|Icons:$current_icon_theme|Cursor:$current_cursor_theme"
}

# List available themes with sources and current system theme
list_themes() {
    echo -e "${BLUE}📋 Your Managed Themes:${NC}"
    echo
    
    if [[ -f "$SCRIPT_DIR/theme-config.json" ]]; then
        local counter=1
        local theme_keys=($(jq -r '.themes | keys[]' "$SCRIPT_DIR/theme-config.json"))
        
        for theme_name in "${theme_keys[@]}"; do
            echo -e "  $counter) $theme_name"
            ((counter++))
        done
    else
        echo -e "  ${RED}✗ No theme configuration found${NC}"
        echo
    fi
    
    echo
    
    # Show current system theme
    echo -e "${BLUE}🖥️  Current System Theme:${NC}"
    local system_theme_info=$(get_current_system_theme)
    local gtk_theme=$(echo "$system_theme_info" | grep -o 'GTK:[^|]*' | cut -d: -f2)
    local icon_theme=$(echo "$system_theme_info" | grep -o 'Icons:[^|]*' | cut -d: -f2)
    local cursor_theme=$(echo "$system_theme_info" | grep -o 'Cursor:[^|]*' | cut -d: -f2)
    
    if [[ "$gtk_theme" != "unknown" && -n "$gtk_theme" ]]; then
        echo -e "  GTK Theme: ${GREEN}$gtk_theme${NC}"
    else
        echo -e "  GTK Theme: ${YELLOW}Not detected${NC}"
    fi
    
    if [[ "$icon_theme" != "unknown" && -n "$icon_theme" ]]; then
        echo -e "  Icon Theme: ${GREEN}$icon_theme${NC}"
    else
        echo -e "  Icon Theme: ${YELLOW}Not detected${NC}"
    fi
    
    if [[ "$cursor_theme" != "unknown" && -n "$cursor_theme" ]]; then
        echo -e "  Cursor Theme: ${GREEN}$cursor_theme${NC}"
    else
        echo -e "  Cursor Theme: ${YELLOW}Not detected${NC}"
    fi
    
    echo
}

# Set active theme
set_theme() {
    local theme_name="$1"
    bash "$SHELL_THEME_SCRIPT" set "$theme_name"
}

# Show help
show_help() {
    echo -e "${BLUE}🎨 Theme Manager${NC}"
    echo
    echo "Manages both color themes (app colors) and shell themes (GTK/UI)"
    echo
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo "  install [--force]        Install complete theme (shell + colors)"
    echo "  install-shell [--force]  Install shell theme only (GTK/Icons/Cursors)"
    echo "  install-colors           Apply color theme only (app colors)"
    echo "  status                   Show complete theme status"
    echo "  list                     List available themes with sources"
    echo "  set <theme>              Set active shell theme"
    echo "  help                     Show this help"
    echo
    echo "Examples:"
    echo "  $0 install                    # Install complete theme"
    echo "  $0 install --force           # Force reinstall everything"
    echo "  $0 install-shell             # Install GTK theme only"
    echo "  $0 install-colors            # Apply app colors only"
    echo "  $0 set mactahoe              # Switch shell theme"
    echo
    echo "Theme Components:"
    echo "  • Shell Theme: GTK themes, icon themes, cursor themes"
    echo "  • Color Theme: Application colors (starship, kitty, hyprland, etc.)"
}

# Main execution
main() {
    check_scripts
    
    case "${1:-help}" in
        "install")
            install_full "$2"
            ;;
        "install-shell")
            install_shell "$2"
            ;;
        "install-colors")
            install_colors
            ;;
        "status")
            show_status
            ;;
        "list")
            list_themes
            ;;
        "set")
            if [[ -z "$2" ]]; then
                error "Theme name required"
                exit 1
            fi
            set_theme "$2"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@" 