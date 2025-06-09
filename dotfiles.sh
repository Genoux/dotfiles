#!/bin/bash
# Main dotfiles manager - the only script you need to run

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
STOW_DIR="$SCRIPT_DIR/stow"

echo -e "${BLUE}🏠 Dotfiles Manager${NC}"
echo

# Check if we're in the right directory
if [[ ! -d "$SCRIPTS_DIR" || ! -d "$STOW_DIR" ]]; then
    echo -e "${RED}❌ Error: scripts/ or stow/ directory not found${NC}"
    echo "Make sure you're running this from your dotfiles directory"
    exit 1
fi

show_menu() {
    echo -e "${BLUE}📋 What would you like to do?${NC}"
    echo
    echo "📦 PACKAGES:"
    echo "  1) Get current packages     (system → txt files)"
    echo "  2) Install packages         (txt files → system)"
    echo "  3) Preview sync             (show what would change)"
    echo "  4) Install with sync        (remove unlisted packages)"
    echo
    echo "⚙️  CONFIGS:"
    echo "  5) Backup configs          (system → dotfiles)"
    echo "  6) List available configs   (show what's in dotfiles)"
    echo "  7) Install config          (dotfiles → system symlinks)"
    echo "  8) Install all configs     (all dotfiles → system)"
    echo "  9) Remove config           (remove symlinks)"
    echo
    echo "🎨 THEMES:"
    echo "  10) Install themes         (download custom themes)"
    echo
    echo "📊 INFO:"
    echo "  s) Status                  (show current state)"
    echo "  h) Help                    (explain workflow)"
    echo "  q) Quit"
    echo
}

show_status() {
    echo -e "${BLUE}📊 Current Status:${NC}"
    echo
    
    # Package files
    if [[ -f "$SCRIPT_DIR/packages.txt" ]]; then
        echo -e "📦 Official packages: ${GREEN}$(wc -l < "$SCRIPT_DIR/packages.txt")${NC}"
    else
        echo -e "📦 Official packages: ${RED}Not found${NC}"
    fi
    
    if [[ -f "$SCRIPT_DIR/aur-packages.txt" ]]; then
        echo -e "📦 AUR packages: ${GREEN}$(wc -l < "$SCRIPT_DIR/aur-packages.txt")${NC}"
    else
        echo -e "📦 AUR packages: ${RED}Not found${NC}"
    fi
    
    # Config packages
    echo
    if [[ -d "$STOW_DIR" ]]; then
        local config_count=$(find "$STOW_DIR" -maxdepth 1 -type d ! -name ".*" | wc -l)
        ((config_count--)) # Remove stow dir itself from count
        echo -e "⚙️  Available configs: ${GREEN}$config_count${NC}"
        
        if [[ $config_count -gt 0 ]]; then
            echo "   Configs:"
            for config in "$STOW_DIR"/*; do
                if [[ -d "$config" && "$(basename "$config")" != "." && "$(basename "$config")" != ".." ]]; then
                    config_name=$(basename "$config")
                    if [[ "$config_name" != "manage-configs.sh" ]]; then
                        # Check if stowed
                        if [[ -L "$HOME/.config/$config_name" ]]; then
                            echo -e "     ${GREEN}✓${NC} $config_name (linked)"
                        else
                            echo -e "     ${YELLOW}○${NC} $config_name (not linked)"
                        fi
                    fi
                fi
            done
        fi
    else
        echo -e "⚙️  Configs: ${RED}stow/ directory not found${NC}"
    fi
    echo
}

show_help() {
    echo -e "${BLUE}💡 Dotfiles Workflow:${NC}"
    echo
    echo -e "${YELLOW}First Time Setup:${NC}"
    echo "  1. Get current packages (saves what you have)"
    echo "  2. Backup configs (saves your current configs)"
    echo "  3. Install all configs (creates symlinks)"
    echo
    echo -e "${YELLOW}Daily Usage:${NC}"
    echo "  • Edit configs normally (~/config/app/)"
    echo "  • Changes automatically save to dotfiles"
    echo "  • Commit/push when ready"
    echo
    echo -e "${YELLOW}New Machine:${NC}"
    echo "  1. Clone dotfiles repo"
    echo "  2. Install packages"
    echo "  3. Install all configs"
    echo
    echo -e "${YELLOW}Adding New Software:${NC}"
    echo "  1. Install software normally"
    echo "  2. Get current packages (updates lists)"
    echo "  3. Backup configs (if app has configs you want)"
    echo
}

run_script() {
    local script="$1"
    local description="$2"
    
    echo -e "${BLUE}🚀 $description...${NC}"
    echo
    
    if [[ -f "$SCRIPTS_DIR/$script" ]]; then
        cd "$SCRIPT_DIR"
        bash "$SCRIPTS_DIR/$script" "${@:3}"
    else
        echo -e "${RED}❌ Script not found: $SCRIPTS_DIR/$script${NC}"
        return 1
    fi
}

run_stow_script() {
    local command="$1"
    local description="$2"
    
    echo -e "${BLUE}🔗 $description...${NC}"
    echo
    
    if [[ -f "$STOW_DIR/manage-configs.sh" ]]; then
        cd "$STOW_DIR"
        bash manage-configs.sh "$command" "${@:3}"
    else
        echo -e "${RED}❌ Stow manager not found: $STOW_DIR/manage-configs.sh${NC}"
        return 1
    fi
}

# Main loop
while true; do
    show_menu
    read -p "Choose an option: " choice
    echo
    
    case $choice in
        1)
            run_script "get-packages.sh" "Getting current packages"
            ;;
        2)
            run_script "install-packages.sh" "Installing packages"
            ;;
        3)
            run_script "preview-sync.sh" "Previewing sync changes"
            ;;
        4)
            run_script "install-packages.sh" "Installing packages with sync" "--sync"
            ;;
        5)
            run_script "backup-configs.sh" "Backing up configs"
            ;;
        6)
            run_stow_script "list" "Listing available configs"
            ;;
        7)
            echo "Available configs:"
            run_stow_script "list" "Showing configs"
            echo
            read -p "Enter config name to install: " config_name
            if [[ ! -z "$config_name" ]]; then
                run_stow_script "install" "Installing $config_name" "$config_name"
            fi
            ;;
        8)
            run_stow_script "install" "Installing all configs" "all"
            ;;
        9)
            echo "Available configs:"
            run_stow_script "list" "Showing configs"
            echo
            read -p "Enter config name to remove: " config_name
            if [[ ! -z "$config_name" ]]; then
                run_stow_script "remove" "Removing $config_name" "$config_name"
            fi
            ;;
        10)
            run_script "install-themes.sh" "Installing themes"
            ;;
        s|S)
            show_status
            ;;
        h|H)
            show_help
            ;;
        q|Q)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option. Try again.${NC}"
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    echo
done