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
    echo "  1) Complete Setup           (everything: packages + shell + themes + configs)"
    echo
    echo "📦 PACKAGES:"
    echo "  2) Smart Sync               (auto-sync packages)"
    echo "  3) Package Check            (status + preview changes)"
    echo
    echo "🐚 SHELL:"
    echo "  z) Shell Setup              (zsh + Oh My Zsh + plugins)"
    echo
    echo "⚙️  CONFIGS:"
    echo "  4) List Available Configs   (show what's in dotfiles)"
    echo "  5) Install Config           (dotfiles → system symlinks)"
    echo "  6) Install All Configs      (all dotfiles → system)"
    echo "  7) Remove Config            (remove symlinks)"
    echo
    echo "🎨 THEMES:"
    echo "  t) Install Themes           (WhiteSur GTK + Icons + Cursors)"
    echo
    echo "🖥️  HYPRLAND:"
    echo "  h) Setup Hyprland           (monitors + workspaces + config)"
    echo
    echo "📊 INFO:"
    echo "  s) Status                   (show current state)"
    echo "  help) Help                  (explain workflow)"
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
    
    # Shell status
    echo
    echo -e "${BLUE}🐚 Shell Status:${NC}"
    if command -v zsh &> /dev/null; then
        echo -e "   zsh: ${GREEN}✓ $(zsh --version | cut -d' ' -f2)${NC}"
    else
        echo -e "   zsh: ${RED}✗ Not installed${NC}"
    fi
    
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        echo -e "   Oh My Zsh: ${GREEN}✓ Installed${NC}"
    else
        echo -e "   Oh My Zsh: ${RED}✗ Not installed${NC}"
    fi
    
    # Check plugins (dynamic from zsh-plugins.txt)
    local plugin_status=""
    local plugin_count=0
    if [[ -f "$SCRIPT_DIR/zsh-plugins.txt" ]]; then
        while IFS= read -r plugin_line; do
            [[ -z "$plugin_line" ]] && continue
            local plugin_name=$(echo "$plugin_line" | cut -d':' -f1)
            if [[ -d "$HOME/.oh-my-zsh/custom/plugins/$plugin_name" ]]; then
                plugin_status="${plugin_status}✓ "
            else
                plugin_status="${plugin_status}✗ "
            fi
            ((plugin_count++))
        done < <(grep -v '^#' "$SCRIPT_DIR/zsh-plugins.txt" | grep -v '^[[:space:]]*$')
    fi
    
    if [[ $plugin_count -gt 0 ]]; then
        echo -e "   Plugins ($plugin_count): ${plugin_status}"
    else
        echo -e "   Plugins: ${YELLOW}⚠ No plugin list found${NC}"
    fi
    
    # Default shell
    local current_shell=$(getent passwd "$USER" | cut -d: -f7 2>/dev/null || echo "$SHELL")
    local zsh_path=$(which zsh 2>/dev/null || echo "")
    if [[ "$current_shell" == "$zsh_path" && -n "$zsh_path" ]]; then
        echo -e "   Default shell: ${GREEN}✓ zsh${NC}"
    else
        echo -e "   Default shell: ${YELLOW}⚠ $(basename "$current_shell")${NC}"
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
    echo -e "${BLUE}💡 Enhanced Dotfiles Workflow:${NC}"
    echo
    echo -e "${YELLOW}🚀 Quick Start (Recommended):${NC}"
    echo "  • Run 'Complete Setup' - it handles EVERYTHING!"
    echo "  • Packages → shell → configs with auto Hyprland setup"
    echo "  • Themes available separately if needed"
    echo
    echo -e "${YELLOW}🏠 On Current System:${NC}"
    echo "  2. Smart Sync (packages)"
    echo "  z. Shell Setup (zsh + Oh My Zsh + plugins)"  
    echo "  3. Install All Configs (force or backup mode)"
    echo "  5. Install Single Config (force or backup mode)"
    echo "  h. Hyprland Setup (device-specific monitors - auto-runs during config install)"
    echo
    echo -e "${YELLOW}🆕 On New Machine:${NC}"
    echo "  1. Clone dotfiles repo"
    echo "  2. Complete Setup (packages → shell → configs with Hyprland auto-setup)"
    echo "  3. Log out and back in for shell changes"
    echo "  4. Done! Everything synced automatically"
    echo
    echo -e "${YELLOW}📦 Package Management:${NC}"
    echo "  • Smart hardware detection (NVIDIA filtering)"
    echo "  • Combined status + preview in one command"
    echo "  • Automatic dependency detection"
    echo "  • Handles both official and AUR packages"
    echo
    echo -e "${YELLOW}🐚 Shell Features:${NC}"
    echo "  • Automatic zsh + Oh My Zsh installation"
    
    # Dynamic plugin display from zsh-plugins.txt
    if [[ -f "$SCRIPT_DIR/zsh-plugins.txt" ]]; then
        local plugin_names=()
        while IFS= read -r plugin_line; do
            [[ -z "$plugin_line" ]] && continue
            plugin_names+=($(echo "$plugin_line" | cut -d':' -f1))
        done < <(grep -v '^#' "$SCRIPT_DIR/zsh-plugins.txt" | grep -v '^[[:space:]]*$')
        
        if [[ ${#plugin_names[@]} -gt 0 ]]; then
            local plugin_list=$(IFS=' & '; echo "${plugin_names[*]}")
            echo "  • $plugin_list"
        else
            echo "  • Configurable zsh plugins (edit zsh-plugins.txt)"
        fi
    else
        echo "  • Configurable zsh plugins (create zsh-plugins.txt)"
    fi
    
    echo "  • Custom themes and configurations"
    echo "  • Sets zsh as default shell"
    echo
    echo -e "${YELLOW}🖥️  Hyprland Features:${NC}"
    echo "  • Auto-detects monitors and generates config"
    echo "  • Device-specific scaling (laptop vs desktop)"
    echo "  • Only monitors.conf is generated - input/appearance stay universal"
    echo "  • Auto-runs when installing hypr config - no manual setup needed"
    echo "  • Keeps git clean - no device conflicts"
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
    echo -e "${GREEN}💡 Pro tip: 'Complete Setup' is streamlined - no redundant steps!${NC}"
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
            echo -e "${YELLOW}Note: Complete setup uses FORCE mode (overwrites everything)${NC}"
            read -p "Continue with force mode? (Y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                echo "Setup cancelled."
                continue
            fi
            cd "$SCRIPT_DIR"
            

            
            # Step 1: Packages
            echo -e "${BLUE}Step 1: Setting up packages...${NC}"
            bash "$SCRIPTS_DIR/setup-packages.sh" install
            echo
            
            # Step 1.5: Themes
            echo -e "${BLUE}Step 1.5: Setting up themes...${NC}"
            if [[ -f "$SCRIPTS_DIR/setup-themes.sh" ]]; then
                bash "$SCRIPTS_DIR/setup-themes.sh" --quiet
            else
                echo -e "${YELLOW}⚠️  Theme setup script not found, skipping...${NC}"
            fi
            echo
            
            # Step 2: Shell setup  
            echo -e "${BLUE}Step 2: Setting up shell (zsh + Oh My Zsh + plugins)...${NC}"
            if [[ -f "$SCRIPTS_DIR/setup-shell.sh" ]]; then
                bash "$SCRIPTS_DIR/setup-shell.sh"
            else
                echo -e "${YELLOW}⚠️  Shell setup script not found, skipping...${NC}"
            fi
            echo
            
            # Step 3: Install configs (force mode for complete setup)
            echo -e "${BLUE}Step 3: Installing configs (force mode)...${NC}"
            echo -e "${BLUE}3a. Installing system config first (avoids race conditions)...${NC}"
            cd "$STOW_DIR"
            bash manage-configs.sh install system --force
            echo
            
            echo -e "${BLUE}3b. Installing remaining configs...${NC}"
            for config in */; do
                config=${config%/}
                [[ "$config" == "manage-configs.sh" ]] && continue
                [[ "$config" == "system" ]] && continue  # Already installed
                
                # Install config (let manage-configs.sh handle output)
                bash manage-configs.sh install "$config" --force
            done
            echo "🎉 All configs processed!"
            cd "$SCRIPT_DIR"  # Return to dotfiles root
            
            echo
            echo -e "${GREEN}🎉 Complete setup finished!${NC}"
            echo -e "${YELLOW}💡 Next steps:${NC}"
            echo "  • Log out and back in for shell changes to take effect"
            echo "  • Restart desktop environment for themes (if installed)"
            echo "  • Open new terminal to see Oh My Zsh in action"
            echo "  • Hyprland monitors configured automatically"
            ;;
        2)
            echo -e "${BLUE}🚀 Running Smart Sync (the magic button!)${NC}"
            cd "$SCRIPT_DIR"
            bash "$SCRIPTS_DIR/setup-packages.sh" install
            ;;
        3)
            echo -e "${BLUE}📊 Package Check (Status + Preview)${NC}"
            cd "$SCRIPT_DIR"
            bash "$SCRIPTS_DIR/setup-packages.sh" check
            ;;
        4)
            run_stow_script "list" "Listing available configs"
            ;;
        5)
            echo "Available configs:"
            run_stow_script "list" "Showing configs"
            echo
            read -p "Enter config name to install: " config_name
            if [[ ! -z "$config_name" ]]; then
                echo
                echo "Choose installation mode:"
                echo "  1) Force - Just overwrite everything (recommended)"
                echo "  2) Backup - Create .bak files before overwriting"
                read -p "Mode (1-2): " mode_choice
                
                case "$mode_choice" in
                    1) mode_flag="--force" ;;
                    2) mode_flag="--backup" ;;
                    *) mode_flag="--force" ;;  # Default to force
                esac
                
                cd "$STOW_DIR"
                echo -e "${BLUE}🔗 Installing $config_name with $(echo $mode_flag | sed 's/--//' | tr '[:lower:]' '[:upper:]') mode...${NC}"
                bash manage-configs.sh install "$config_name" $mode_flag
            fi
            ;;
        6)
            echo "Choose installation mode for ALL configs:"
            echo "  1) Force - Just overwrite everything (recommended)"
            echo "  2) Backup - Create .bak files before overwriting"
            read -p "Mode (1-2): " mode_choice
            
            case "$mode_choice" in
                1) mode_flag="--force" ;;
                2) mode_flag="--backup" ;;
                *) mode_flag="--force" ;;  # Default to force
            esac
            
            cd "$STOW_DIR"
            echo -e "${BLUE}🔗 Installing ALL configs with $(echo $mode_flag | sed 's/--//' | tr '[:lower:]' '[:upper:]') mode...${NC}"
            bash manage-configs.sh install all $mode_flag
            ;;
        7)
            echo "Available configs:"
            run_stow_script "list" "Showing configs"
            echo
            read -p "Enter config name to remove: " config_name
            if [[ ! -z "$config_name" ]]; then
                run_stow_script "remove" "Removing $config_name" "$config_name"
            fi
            ;;
        z|Z)
            echo -e "${BLUE}🐚 Shell Setup${NC}"
            if [[ -f "$SCRIPTS_DIR/setup-shell.sh" ]]; then
                bash "$SCRIPTS_DIR/setup-shell.sh"
            else
                echo -e "${RED}❌ Shell setup script not found${NC}"
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
                    bash "$SCRIPTS_DIR/setup-themes.sh" --force
                else
                    echo -e "${YELLOW}Using existing themes${NC}"
                fi
            else
                cd "$SCRIPT_DIR"
                bash "$SCRIPTS_DIR/setup-themes.sh"
            fi
            ;;
        h|H)
            echo -e "${BLUE}🖥️  Hyprland Setup${NC}"
            if [[ -f "$SCRIPTS_DIR/setup-hyprland.sh" ]]; then
                bash "$SCRIPTS_DIR/setup-hyprland.sh"
            else
                echo -e "${RED}❌ Hyprland setup script not found${NC}"
            fi
            ;;

        s|S)
            show_status
            ;;
        help)
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