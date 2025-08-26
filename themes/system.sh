#!/bin/bash

# System Theme Manager - Stow-based theme switching
# Usage: ./system.sh [list|setup|switch <theme>]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_DIR="$SCRIPT_DIR"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
APPS_CONFIG="$SCRIPT_DIR/apps.json"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[SYSTEM]${NC} $1"
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

# Get current active theme (check which theme is applied)
get_current_theme() {
    if [[ ! -d "$HOME/.config/themes/current" ]]; then
        echo "none"
        return
    fi
    
    # Try to determine current theme by comparing file contents
    for theme_dir in "$THEMES_DIR"/*; do
        if [[ -d "$theme_dir" ]]; then
            local theme_name=$(basename "$theme_dir")
            [[ "$theme_name" == "apps" ]] && continue
            
            # Check if any file matches
            local matches=0
            local total=0
            for file in "$theme_dir"/*; do
                if [[ -f "$file" ]]; then
                    local basename=$(basename "$file")
                    local current_file="$HOME/.config/themes/current/$basename"
                    ((total++))
                    if [[ -f "$current_file" ]] && cmp -s "$file" "$current_file"; then
                        ((matches++))
                    fi
                fi
            done
            
            # If all files match, this is the current theme
            if [[ $matches -gt 0 && $matches -eq $total ]]; then
                echo "$theme_name"
                return
            fi
        fi
    done
    
    echo "unknown"
}

# List all available themes with status
list_themes() {
    local current_theme=$(get_current_theme)
    
    echo -e "${BLUE}📋 Available System Themes:${NC}"
    echo
    
    # Look for theme folders in dotfiles/themes/
    for theme_dir in "$THEMES_DIR"/*; do
        if [[ -d "$theme_dir" ]]; then
            local theme_name=$(basename "$theme_dir")
            
            # Skip non-theme directories
            [[ "$theme_name" == "apps" ]] && continue
            
            if [[ "$theme_name" == "$current_theme" ]]; then
                echo -e "  ${GREEN}✓ $theme_name${NC}"
            else
                echo -e "    $theme_name"
            fi
        fi
    done
}

# Switch to a theme
switch_theme() {
    local theme_name="$1"
    
    if [[ -z "$theme_name" ]]; then
        error "Theme name required"
        echo "Usage: $0 switch <theme_name>"
        return 1
    fi
    
    if [[ ! -d "$THEMES_DIR/$theme_name" ]]; then
        error "Theme '$theme_name' not found in $THEMES_DIR"
        return 1
    fi
    
    log "Switching to theme: $theme_name"
    
    # Create target directory
    mkdir -p "$HOME/.config/themes/current"
    
    # Copy all theme files dynamically based on app configuration
    for file in "$THEMES_DIR/$theme_name"/*; do
        if [[ -f "$file" ]]; then
            local basename=$(basename "$file")
            local app_name="${basename%.*}"
            
            # Get app configuration from apps.json
            local app_config=$(jq -r ".apps.\"$app_name\"" "$APPS_CONFIG" 2>/dev/null)
            
            if [[ "$app_config" == "null" || -z "$app_config" ]]; then
                # Default: centralized for unknown apps
                cp "$file" "$HOME/.config/themes/current/"
                log "Copied $app_name theme (default: centralized)"
            else
                local app_type=$(echo "$app_config" | jq -r '.type')
                
                case "$app_type" in
                    "direct")
                        local target=$(echo "$app_config" | jq -r '.target' | sed "s|~|$HOME|g")
                        local target_dir=$(dirname "$target")
                        mkdir -p "$target_dir"
                        cp "$file" "$target"
                        log "Applied $app_name theme directly to $target"
                        ;;
                    "themes_dir")
                        local target=$(echo "$app_config" | jq -r '.target' | sed "s|~|$HOME|g")
                        local target_dir=$(dirname "$target")
                        mkdir -p "$target_dir"
                        cp "$file" "$target"
                        log "Applied $app_name theme to themes directory"
                        ;;
                    "centralized"|*)
                        cp "$file" "$HOME/.config/themes/current/"
                        log "Copied $app_name theme (centralized)"
                        ;;
                esac
            fi
        fi
    done
    
    success "Switched to theme: $theme_name"
    echo
    echo -e "${YELLOW}Restart applications to apply changes:${NC}"
}

# Setup theme system (ask which theme to activate)
setup_themes() {
    log "Setting up theme system..."
    
    # Check if we have any themes available
    local available_themes=()
    for theme_dir in "$THEMES_DIR"/*; do
        if [[ -d "$theme_dir" && "$(basename "$theme_dir")" != "current" ]]; then
            available_themes+=("$(basename "$theme_dir")")
        fi
    done
    
    if [[ ${#available_themes[@]} -eq 0 ]]; then
        error "No themes found in $THEMES_DIR"
        echo "Create theme directories like: $THEMES_DIR/dark/, $THEMES_DIR/light/"
        return 1
    fi
    
    # Show available themes
    echo "Available themes:"
    for i in "${!available_themes[@]}"; do
        echo "  $((i+1))) ${available_themes[i]}"
    done
    
    # Ask user to pick a theme
    echo -n "Choose theme to setup (1-${#available_themes[@]}): "
    read -r choice
    
    # Validate choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#available_themes[@]} ]]; then
        error "Invalid choice"
        return 1
    fi
    
    local selected_theme="${available_themes[$((choice-1))]}";
    log "Setting up theme: $selected_theme"
    
    # Use the switch_theme function to deploy the selected theme
    switch_theme "$selected_theme"
    
    success "Theme system ready with '$selected_theme' theme!"
}

# Main command handling
case "$1" in
    list|"")
        list_themes
        ;;
    setup)
        setup_themes
        ;;
    switch)
        switch_theme "$2"
        ;;
    *)
        echo "Usage: $0 {list|setup|switch <theme>}"
        echo
        echo "Commands:"
        echo "  list     - List all available themes"
        echo "  setup    - Initialize theme system"  
        echo "  switch   - Switch to specified theme"
        exit 1
        ;;
esac
