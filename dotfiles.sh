#!/bin/bash
# Main dotfiles manager - the only script you need to run
# dotfiles.sh
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
    echo "🚀 QUICK SETUP:"
    echo "  1) Complete Setup           (everything: packages + themes + configs)"
    echo
    echo "📦 PACKAGES:"
    echo "  2) Smart Sync               (auto-sync packages)"
    echo "  3) Package Status           (show what would change)"
    echo "  4) Package Preview          (detailed view)"
    echo
    echo "⚙️  CONFIGS:"
    echo "  5) List Available Configs   (show what's in dotfiles)"
    echo "  6) Install Config           (dotfiles → system symlinks)"
    echo "  7) Install All Configs      (all dotfiles → system)"
    echo "  8) Remove Config            (remove symlinks)"
    echo
    echo "🎨 THEMES:"
    echo "  t) Install Themes           (download custom themes)"
    echo
    echo "🖥️  MONITOR:"
    echo "  m) Setup Monitors           (auto-detect and configure)"
    echo
    echo "📊 INFO:"
    echo "  s) Status                   (show current state)"
    echo "  h) Help                     (explain workflow)"
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
            # Use manage-configs.sh for accurate status (DRY principle)
            cd "$STOW_DIR"
            ./manage-configs.sh list | grep -E "^\s*[✅⭕]" | sed 's/✅/✓/g; s/⭕/○/g' | while read line; do
                if [[ "$line" == *"✓"* ]]; then
                    echo -e "     ${GREEN}$(echo "$line" | sed 's/✓/✓/')${NC}"
                else
                    echo -e "     ${YELLOW}$(echo "$line" | sed 's/○/○/')${NC}"
                fi
            done
        fi
    else
        echo -e "⚙️  Configs: ${RED}stow/ directory not found${NC}"
    fi
    echo
}

show_help() {
    echo -e "${BLUE}💡 Simplified Dotfiles Workflow:${NC}"
    echo
    echo -e "${YELLOW}🚀 Quick Start (Recommended):${NC}"
    echo "  • Just run 'Smart Sync' - it handles everything!"
    echo "  • Then 'Install All Configs' to deploy your settings"
    echo
    echo -e "${YELLOW}🏠 On Current System:${NC}"
    echo "  1. Smart Sync (auto-gets packages + syncs)"
    echo "  2. Install All Configs (deploy settings)"
    echo "  3. Edit configs normally in ~/.config/"
    echo
    echo -e "${YELLOW}🆕 On New Machine:${NC}"
    echo "  1. Clone dotfiles repo"
    echo "  2. Complete Setup (does everything)"
    echo "  3. Done! Everything synced automatically"
    echo
    echo -e "${YELLOW}➕ Adding New Software:${NC}"
    echo "  1. Install software normally (pacman/yay)"
    echo "  2. Smart Sync (updates package lists automatically)"
    echo
    echo -e "${YELLOW}⚙️  Adding New Configs:${NC}"
    echo "  1. Copy config to stow/ folder:"
    echo "     cp -r ~/.config/newapp stow/newapp/.config/"
    echo "  2. Install Config 'newapp'"
    echo "  3. Done! Now it's managed by dotfiles"
    echo
    echo -e "${GREEN}💡 Pro tip: 'Smart Sync' does everything automatically!${NC}"
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
            echo -e "${BLUE}🎯 Complete Setup - Everything at once!${NC}"
            cd "$SCRIPT_DIR"
            bash "$SCRIPTS_DIR/manage-packages.sh" setup
            echo
            echo -e "${BLUE}🖥️  Setting up monitors...${NC}"
            if [[ -f "$SCRIPTS_DIR/setup-monitors.sh" ]]; then
                bash "$SCRIPTS_DIR/setup-monitors.sh" --quiet
            else
                echo -e "${YELLOW}⚠️  Monitor setup script not found, skipping...${NC}"
            fi
            echo
            echo -e "${BLUE}Installing all configs...${NC}"
            run_stow_script "install" "Installing all configs" "all"
            ;;
        2)
            echo -e "${BLUE}🚀 Running Smart Sync (the magic button!)${NC}"
            cd "$SCRIPT_DIR"
            bash "$SCRIPTS_DIR/manage-packages.sh"
            ;;
        3)
            echo -e "${BLUE}📊 Package Status${NC}"
            cd "$SCRIPT_DIR"
            bash "$SCRIPTS_DIR/manage-packages.sh" status
            ;;
        4)
            echo -e "${BLUE}🔍 Detailed Package Preview${NC}"
            cd "$SCRIPT_DIR"
            bash "$SCRIPTS_DIR/manage-packages.sh" preview
            ;;
        5)
            run_stow_script "list" "Listing available configs"
            ;;
        6)
            echo "Available configs:"
            run_stow_script "list" "Showing configs"
            echo
            read -p "Enter config name to install: " config_name
            if [[ ! -z "$config_name" ]]; then
                run_stow_script "install" "Installing $config_name" "$config_name"
            fi
            ;;
        7)
            run_stow_script "install" "Installing all configs" "all"
            ;;
        8)
            echo "Available configs:"
            run_stow_script "list" "Showing configs"
            echo
            read -p "Enter config name to remove: " config_name
            if [[ ! -z "$config_name" ]]; then
                run_stow_script "remove" "Removing $config_name" "$config_name"
            fi
            ;;
        t|T)
            echo -e "${BLUE}🎨 Installing Themes${NC}"
            
            # Check if themes are already installed
            themes_exist=false
            if [[ -d "$HOME/.themes/WhiteSur-Light" ]] || \
               [[ -d "$HOME/.icons/WhiteSur" ]] || [[ -d "$HOME/.local/share/icons/WhiteSur" ]] || \
               [[ -d "$HOME/.icons/WhiteSur-cursors" ]] || [[ -d "$HOME/.local/share/icons/WhiteSur-cursors" ]]; then
                themes_exist=true
            fi
            
            if $themes_exist; then
                echo
                echo -e "${YELLOW}🔍 WhiteSur themes are already installed${NC}"
                read -p "Force reinstall to update? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    cd "$SCRIPT_DIR"
                    bash "$SCRIPTS_DIR/manage-packages.sh" themes --force
                else
                    echo -e "${YELLOW}Using existing themes${NC}"
                fi
            else
                cd "$SCRIPT_DIR"
                bash "$SCRIPTS_DIR/manage-packages.sh" themes
            fi
            ;;
        m|M)
            echo -e "${BLUE}🖥️  Monitor Setup${NC}"
            if [[ -f "$SCRIPTS_DIR/setup-monitors.sh" ]]; then
                bash "$SCRIPTS_DIR/setup-monitors.sh"
            else
                echo -e "${RED}❌ Monitor setup script not found${NC}"
            fi
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