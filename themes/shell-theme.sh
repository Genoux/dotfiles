#!/bin/bash

# Theme Manager Script
# Manages GTK themes, icons, and cursors based on theme-config.json

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/theme-config.json"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[THEME]${NC} $1"
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

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        echo "Install with: sudo pacman -S ${missing[*]}"
        exit 1
    fi
}

# Check if theme config exists
check_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Theme config not found: $CONFIG_FILE"
        exit 1
    fi
}

# Get active theme name
get_active_theme() {
    jq -r '.active_theme' "$CONFIG_FILE"
}

# Get theme config
get_theme_config() {
    local theme_name="$1"
    jq -r ".themes.\"$theme_name\"" "$CONFIG_FILE"
}

# Check if theme exists in config
theme_exists() {
    local theme_name="$1"
    local theme_config=$(get_theme_config "$theme_name")
    [[ "$theme_config" != "null" ]]
}

# Clone and install component (gtk, icons, cursors)
install_component() {
    local component_name="$1"
    local repo_url="$2"
    local install_cmd="$3"
    local theme_name="$4"
    
    log "Installing $component_name for $theme_name..."
    
    local temp_dir=$(mktemp -d)
    local repo_name=$(basename "$repo_url" .git)
    local original_dir=$(pwd)
    
    if git clone "$repo_url" "$temp_dir/$repo_name"; then
        cd "$temp_dir/$repo_name"
        
        if eval "$install_cmd"; then
            success "$component_name installed successfully"
            cd "$original_dir"
            rm -rf "$temp_dir"
            return 0
        else
            error "Failed to install $component_name"
            cd "$original_dir"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        error "Failed to clone $repo_url"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Check installation status
check_component_status() {
    local component_type="$1"
    local theme_name="$2"
    
    case "$component_type" in
        "gtk")
            [[ -d "$HOME/.themes/$theme_name" ]] && echo "installed" || echo "missing"
            ;;
        "icons")
            ([[ -d "$HOME/.icons/$theme_name" ]] || [[ -d "$HOME/.local/share/icons/$theme_name" ]]) && echo "installed" || echo "missing"
            ;;
        "cursors")
            ([[ -d "$HOME/.icons/$theme_name" ]] || [[ -d "$HOME/.local/share/icons/$theme_name" ]]) && echo "installed" || echo "missing"
            ;;
    esac
}

# Install active theme
install_theme() {
    local force="$1"
    
    log "Installing all themes from config..."
    echo
    
    local total_failed=0
    local theme_keys=($(jq -r '.themes | keys[]' "$CONFIG_FILE"))
    
    for theme_name in "${theme_keys[@]}"; do
        if ! theme_exists "$theme_name"; then
            error "Theme '$theme_name' not found in config"
            continue
        fi
        
        local theme_config=$(get_theme_config "$theme_name")
        local theme_display_name=$(echo "$theme_config" | jq -r '.name')
        
        log "Installing: $theme_display_name"
        echo
        
        local failed=0
        
        # Install GTK theme
        if echo "$theme_config" | jq -e '.gtk' > /dev/null; then
            local gtk_repo=$(echo "$theme_config" | jq -r '.gtk.repo')
            local gtk_cmd=$(echo "$theme_config" | jq -r '.gtk.install_cmd')
            local gtk_theme_name=$(echo "$theme_config" | jq -r '.gtk.theme_name // empty')
            
            install_component "GTK theme" "$gtk_repo" "$gtk_cmd" "$theme_name" || ((failed++))
        fi
        
        # Install icons
        if echo "$theme_config" | jq -e '.icons' > /dev/null; then
            local icons_repo=$(echo "$theme_config" | jq -r '.icons.repo')
            local icons_cmd=$(echo "$theme_config" | jq -r '.icons.install_cmd')
            local icons_theme_name=$(echo "$theme_config" | jq -r '.icons.theme_name // empty')
            
            install_component "Icon theme" "$icons_repo" "$icons_cmd" "$theme_name" || ((failed++))
        fi
        
        # Install cursors
        if echo "$theme_config" | jq -e '.cursors' > /dev/null; then
            local cursors_repo=$(echo "$theme_config" | jq -r '.cursors.repo')
            local cursors_cmd=$(echo "$theme_config" | jq -r '.cursors.install_cmd')
            local cursors_theme_name=$(echo "$theme_config" | jq -r '.cursors.theme_name // empty')
            
            install_component "Cursor theme" "$cursors_repo" "$cursors_cmd" "$theme_name" || ((failed++))
        fi
        
        if [[ $failed -eq 0 ]]; then
            success "Theme '$theme_display_name' installed successfully!"
        else
            error "$failed component(s) failed to install for '$theme_display_name'"
            ((total_failed++))
        fi
        echo
    done
    
    echo
    if [[ $total_failed -eq 0 ]]; then
        success "All themes installed successfully!"
        
        # Auto-activate the active theme from config
        local active_theme=$(get_active_theme)
        log "Setting active theme: $active_theme"
        
        # Try to find and set the installed theme
        if command -v gsettings &> /dev/null; then
            # Look for installed themes that match the active theme repo name
            local found_theme=""
            
            # Common theme name patterns based on repo names
            case "$active_theme" in
                *"MacTahoe"*)
                    for theme in "Tahoe-Dark" "MacTahoe-Dark" "Tahoe" "MacTahoe"; do
                        if [[ -d "$HOME/.themes/$theme" ]]; then
                            found_theme="$theme"
                            break
                        fi
                    done
                    ;;
                *"WhiteSur"*)
                    for theme in "WhiteSur-Dark" "WhiteSur-dark" "WhiteSur" "WhiteSur-Dark-solid"; do
                        if [[ -d "$HOME/.themes/$theme" ]]; then
                            found_theme="$theme"
                            break
                        fi
                    done
                    ;;
                *)
                    # Generic fallback - look for any theme directory that contains part of the repo name
                    local repo_base=$(echo "$active_theme" | cut -d'/' -f2 | sed 's/-gtk-theme//; s/-theme//')
                    for theme_dir in "$HOME/.themes"/*; do
                        if [[ -d "$theme_dir" ]]; then
                            local theme_name=$(basename "$theme_dir")
                            if [[ "$theme_name" == *"$repo_base"* ]]; then
                                found_theme="$theme_name"
                                break
                            fi
                        fi
                    done
                    ;;
            esac
            
            if [[ -n "$found_theme" ]]; then
                gsettings set org.gnome.desktop.interface gtk-theme "$found_theme"
                success "System theme set to: $found_theme"
            else
                warning "Could not auto-detect theme name for $active_theme"
                echo "  Use nwg-look to manually select the theme"
            fi
        fi
    else
        error "$total_failed theme(s) had installation failures"
        exit 1
    fi
}

# List available themes
list_themes() {
    local active_theme=$(get_active_theme)
    
    echo -e "${BLUE}📋 Available Themes:${NC}"
    echo
    
    jq -r '.themes | keys[]' "$CONFIG_FILE" | while read theme_name; do
        local theme_config=$(get_theme_config "$theme_name")
        local display_name=$(echo "$theme_config" | jq -r '.name')
        local description=$(echo "$theme_config" | jq -r '.description')
        
        # Extract git repo information
        local git_repo=""
        if echo "$theme_config" | jq -e '.gtk.repo' > /dev/null; then
            git_repo=$(echo "$theme_config" | jq -r '.gtk.repo')
        elif echo "$theme_config" | jq -e '.icons.repo' > /dev/null; then
            git_repo=$(echo "$theme_config" | jq -r '.icons.repo')
        elif echo "$theme_config" | jq -e '.cursors.repo' > /dev/null; then
            git_repo=$(echo "$theme_config" | jq -r '.cursors.repo')
        fi
        
        # Format repo name for display
        local repo_display=""
        if [[ -n "$git_repo" ]]; then
            # Extract owner/repo from URL
            local repo_name=$(echo "$git_repo" | sed 's/.*github\.com\///; s/\.git$//')
            repo_display="${YELLOW}[${repo_name}]${NC}"
        fi
        
        if [[ "$theme_name" == "$active_theme" ]]; then
            echo -e "  ${GREEN}✓ $display_name${NC} (active) $repo_display"
        else
            echo -e "    $display_name $repo_display"
        fi
        echo -e "    ${YELLOW}→${NC} $description"
        echo
    done
}

# Show status
show_status() {
    local active_theme=$(get_active_theme)
    local theme_config=$(get_theme_config "$active_theme")
    local theme_display_name=$(echo "$theme_config" | jq -r '.name')
    
    echo -e "${BLUE}📊 Theme Status:${NC}"
    echo
    echo -e "Active theme: ${GREEN}$theme_display_name${NC} ($active_theme)"
    echo
    
    # Check GTK theme
    if echo "$theme_config" | jq -e '.gtk' > /dev/null; then
        local gtk_theme_name=$(echo "$theme_config" | jq -r '.gtk.theme_name // empty')
        local gtk_status=$(check_component_status "gtk" "$gtk_theme_name")
        if [[ "$gtk_status" == "installed" ]]; then
            echo -e "  GTK theme: ${GREEN}✓ Installed${NC}"
        else
            echo -e "  GTK theme: ${RED}✗ Missing${NC}"
        fi
    fi
    
    # Check icons
    if echo "$theme_config" | jq -e '.icons' > /dev/null; then
        local icons_theme_name=$(echo "$theme_config" | jq -r '.icons.theme_name // empty')
        local icons_status=$(check_component_status "icons" "$icons_theme_name")
        if [[ "$icons_status" == "installed" ]]; then
            echo -e "  Icon theme: ${GREEN}✓ Installed${NC}"
        else
            echo -e "  Icon theme: ${RED}✗ Missing${NC}"
        fi
    fi
    
    # Check cursors
    if echo "$theme_config" | jq -e '.cursors' > /dev/null; then
        local cursors_theme_name=$(echo "$theme_config" | jq -r '.cursors.theme_name // empty')
        local cursors_status=$(check_component_status "cursors" "$cursors_theme_name")
        if [[ "$cursors_status" == "installed" ]]; then
            echo -e "  Cursor theme: ${GREEN}✓ Installed${NC}"
        else
            echo -e "  Cursor theme: ${RED}✗ Missing${NC}"
        fi
    fi
    echo
}

# Set active theme
set_theme() {
    local theme_name="$1"
    
    if ! theme_exists "$theme_name"; then
        error "Theme '$theme_name' not found in config"
        echo
        echo "Available themes:"
        jq -r '.themes | keys[]' "$CONFIG_FILE" | sed 's/^/  /'
        exit 1
    fi
    
    jq ".active_theme = \"$theme_name\"" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    success "Active theme set to: $theme_name"
    echo
    echo "Run './theme-manager.sh install' to install the new theme"
}

# Show help
show_help() {
    echo -e "${BLUE}🎨 Theme Manager${NC}"
    echo
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo "  install [--force]    Install active theme"
    echo "  list                 List available themes with sources"
    echo "  status               Show installation status"
    echo "  set <theme>          Set active theme"
    echo "  help                 Show this help"
    echo
    echo "Examples:"
    echo "  $0 install                    # Install active theme"
    echo "  $0 install --force           # Force reinstall active theme"
    echo "  $0 set whitesur              # Switch to WhiteSur theme"
    echo "  $0 list                      # Show available themes"
}

# Main execution
main() {
    check_dependencies
    check_config
    
    case "${1:-help}" in
        "install")
            install_theme "$2"
            ;;
        "list")
            list_themes
            ;;
        "status")
            show_status
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