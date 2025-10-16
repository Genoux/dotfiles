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
    echo "  2) Smart Sync               (system → dotfiles + dependencies)"
    echo "  3) Package Check            (preview sync changes)"
    echo
    echo "🐚 SHELL:"
    echo "  z) Shell Setup              (zsh + Oh My Zsh + plugins)"
    echo
    echo "⚙️  CONFIGS:"
    echo "  4) Install Config           (shows status + install specific)"
    echo "  5) Install All Configs      (all dotfiles → system)"
    echo "  6) Remove Config            (remove symlinks)"
    echo
    echo "🎨 THEMES:"
    echo "  t) Theme Management         (unified themes + current system theme)"
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
    echo -e "${BLUE}📊 Dotfiles Status${NC}"
    echo
    
    # Package Status
    echo -e "${BLUE}📦 Package Status:${NC}"
    if [[ -f "$SCRIPT_DIR/packages.txt" ]]; then
        local pkg_count=$(grep -v '^#' "$SCRIPT_DIR/packages.txt" | grep -v '^[[:space:]]*$' | wc -l)
        echo -e "   Official: ${GREEN}$pkg_count packages${NC}"
    else
        echo -e "   Official: ${RED}packages.txt missing${NC}"
    fi
    
    if [[ -f "$SCRIPT_DIR/aur-packages.txt" ]]; then
        local aur_count=$(grep -v '^#' "$SCRIPT_DIR/aur-packages.txt" | grep -v '^[[:space:]]*$' | wc -l)
        echo -e "   AUR: ${GREEN}$aur_count packages${NC}"
    else
        echo -e "   AUR: ${RED}aur-packages.txt missing${NC}"
    fi
    echo
    
    # Shell Status
    echo -e "${BLUE}🐚 Shell Status:${NC}"
    if command -v zsh &> /dev/null; then
        echo -e "   zsh: ${GREEN}✓ Installed${NC}"
    else
        echo -e "   zsh: ${RED}✗ Missing${NC}"
    fi
    
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        echo -e "   Oh My Zsh: ${GREEN}✓ Installed${NC}"
    else
        echo -e "   Oh My Zsh: ${RED}✗ Missing${NC}"
    fi
    
    # Check plugins
    if [[ -f "$SCRIPT_DIR/zsh-plugins.txt" ]]; then
        local plugin_count=$(grep -v '^#' "$SCRIPT_DIR/zsh-plugins.txt" | grep -v '^[[:space:]]*$' | wc -l)
        local installed_count=0
        
        # Count installed plugins
        while IFS= read -r plugin_line; do
            [[ -z "$plugin_line" ]] && continue
            local plugin_name=$(echo "$plugin_line" | cut -d':' -f1)
            if [[ -d "$HOME/.oh-my-zsh/custom/plugins/$plugin_name" ]]; then
                ((installed_count++))
            fi
        done < <(grep -v '^#' "$SCRIPT_DIR/zsh-plugins.txt" | grep -v '^[[:space:]]*$' | head -20)
        
        if [[ $plugin_count -gt 0 ]]; then
            if [[ $installed_count -eq $plugin_count ]]; then
                echo -e "   Plugins: ${GREEN}✓ All $plugin_count installed${NC}"
            else
                echo -e "   Plugins: ${YELLOW}⚠ $installed_count/$plugin_count installed${NC}"
            fi
        fi
    else
        echo -e "   Plugins: ${RED}zsh-plugins.txt missing${NC}"
    fi
    
    # Default shell
    local current_shell=$(getent passwd "$USER" | cut -d: -f7 2>/dev/null || echo "$SHELL")
    local zsh_path=$(which zsh 2>/dev/null || echo "")
    if [[ "$current_shell" == "$zsh_path" && -n "$zsh_path" ]]; then
        echo -e "   Default shell: ${GREEN}✓ zsh${NC}"
    else
        echo -e "   Default shell: ${YELLOW}⚠ $(basename "$current_shell")${NC}"
    fi
    echo
    
    # Config Status
    echo -e "${BLUE}⚙️  Config Status:${NC}"
    if [[ -d "$STOW_DIR" ]]; then
        # Count config directories (excluding ags.bak which is backup)
        local config_dirs=$(find "$STOW_DIR" -maxdepth 1 -type d ! -name ".*" ! -name "*manage-configs*" ! -name "*.bak" ! -path "$STOW_DIR" | wc -l)
        
        # Count total linkable items (directories + system files)
        local total_items=$(cd "$STOW_DIR" && ./manage-configs.sh list 2>/dev/null | grep -E "✅|❌" | wc -l || echo "0")
        local installed_items=$(cd "$STOW_DIR" && ./manage-configs.sh list 2>/dev/null | grep -c "✅" || echo "0")
        
        echo -e "   Config directories: ${GREEN}$config_dirs available${NC}"
        if [[ $installed_items -eq $total_items ]]; then
            echo -e "   Stowed items: ${GREEN}✓ All $total_items/$total_items linked${NC}"
        else
            echo -e "   Stowed items: ${YELLOW}⚠ $installed_items/$total_items linked${NC}"
        fi
    else
        echo -e "   Configs: ${RED}stow/ directory missing${NC}"
    fi
    echo
    
    # Theme Status
    echo -e "${BLUE}🎨 Theme Status:${NC}"
    if [[ -f "$SCRIPT_DIR/themes/theme-config.json" ]]; then
        local theme_count=$(jq '.themes | length' "$SCRIPT_DIR/themes/theme-config.json" 2>/dev/null || echo "0")
        echo -e "   Configured: ${GREEN}$theme_count themes${NC}"
        
        # Check current GTK theme
        if command -v gsettings &>/dev/null; then
            local current_gtk=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'" || echo "unknown")
            echo -e "   Current GTK: ${GREEN}$current_gtk${NC}"
        fi
        
        # Check which apps have theme colors applied
        if [[ -d "$SCRIPT_DIR/themes/apps" ]]; then
            local app_configs=($(find "$SCRIPT_DIR/themes/apps" -name "*.json" -exec basename {} .json \; | sort))
            if [[ ${#app_configs[@]} -gt 0 ]]; then
                echo -e "   App colors: ${GREEN}$(IFS=', '; echo "${app_configs[*]}")${NC}"
            else
                echo -e "   App colors: ${YELLOW}No apps configured${NC}"
            fi
        else
            echo -e "   App colors: ${RED}apps/ directory missing${NC}"
        fi
    else
        echo -e "   Themes: ${RED}theme-config.json missing${NC}"
    fi
    echo
    
    # Hyprland Status
    echo -e "${BLUE}🖥️  Hyprland Status:${NC}"
    if command -v hyprctl &>/dev/null; then
        # Try to get version from binary directly first, then fallback to hyprctl
        local hypr_version="unknown"
        if command -v Hyprland &>/dev/null; then
            hypr_version=$(Hyprland --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        fi
        if [[ "$hypr_version" == "unknown" ]] && hyprctl version &>/dev/null; then
            hypr_version=$(hyprctl version 2>/dev/null | head -1 | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        fi
        echo -e "   Version: ${GREEN}$hypr_version${NC}"
        
        # Monitor config path
        local monitor_config="$HOME/.config/hypr/monitors.conf"
        
        # Get monitor details if Hyprland is running
        if hyprctl version &>/dev/null; then
            local monitor_info=$(hyprctl monitors 2>/dev/null | grep "Monitor" | head -1)
            if [[ -n "$monitor_info" ]]; then
                local monitor_name=$(echo "$monitor_info" | awk '{print $2}')
                echo -e "   Monitor: ${GREEN}$monitor_name $monitor_config${NC}"
            else
                echo -e "   Monitor: ${YELLOW}No active monitors $monitor_config${NC}"
            fi
        else
            echo -e "   Monitor: ${YELLOW}Not running $monitor_config${NC}"
        fi
    else
        echo -e "   Status: ${RED}Not installed${NC}"
    fi
    echo
}

show_help() {
    echo -e "${BLUE}Dotfiles Help${NC}"
    echo
    echo -e "${YELLOW}Quick Start:${NC}"
    echo "  1. Complete Setup - installs everything"
    echo
    echo -e "${YELLOW}Commands:${NC}"
    echo "  1. Complete Setup"
    echo "  2. Smart Sync (packages)"
    echo "  z. Shell Setup"  
    echo "  4. Install Config"
    echo "  5. Install All Configs"
    echo "  6. Remove Config"
    echo "  t. Theme Management"
    echo "  h. Hyprland Setup"
    echo "  s. Status"
    echo
    echo -e "${YELLOW}Adding Software:${NC}"
    echo "  1. Install: pacman -S app"
    echo "  2. Run Smart Sync"
    echo
    echo -e "${YELLOW}Adding Configs:${NC}"
    echo "  1. Copy: cp -r ~/.config/app stow/app/.config/"
    echo "  2. Install Config 'app'"
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
            if [[ -f "$SCRIPT_DIR/themes/theme-manager.sh" ]]; then
                cd "$SCRIPT_DIR/themes"
                bash theme-manager.sh install
                cd "$SCRIPT_DIR"
            else
                echo -e "${YELLOW}⚠️  Theme manager not found, skipping...${NC}"
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
            echo -e "${GREEN}Complete setup finished!${NC}"
            ;;
        2)
            echo -e "${BLUE}🚀 Smart Sync (System → Dotfiles + Dependencies)${NC}"
            cd "$SCRIPT_DIR"
            bash "$SCRIPTS_DIR/setup-packages.sh" install
            ;;
        3)
            echo -e "${BLUE}📊 Package Check (Preview Sync Changes)${NC}"
            cd "$SCRIPT_DIR"
            bash "$SCRIPTS_DIR/setup-packages.sh" check
            ;;
        4)
            echo "📋 Current config status:"
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
        5)
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
        6)
            echo -e "${BLUE}Available configs: $(cd "$STOW_DIR" && ls -1 | grep -v manage-configs.sh | grep -v '\.sh$' | tr '\n' ' ')${NC}"
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
            echo -e "${BLUE}🎨 Theme Management${NC}"
            echo
            echo "Choose theme system:"
            echo "  1) System Theme Manager     (app colors, unified themes)"
            echo "  2) GTK Theme Manager        (window decorations, icons)"
            read -p "Theme system (1-2): " theme_system
            
            case "$theme_system" in
                1)
                    if [[ -f "$SCRIPT_DIR/themes/system.sh" ]]; then
                        echo
                        echo "System Theme Actions:"
                        echo "  1) List all themes"
                        echo "  2) Setup theme system"
                        echo "  3) Switch theme"
                        read -p "Action (1-3): " system_action
                        
                        case "$system_action" in
                            1) bash "$SCRIPT_DIR/themes/system.sh" list ;;
                            2) bash "$SCRIPT_DIR/themes/system.sh" setup ;;
                            3) 
                                echo
                                bash "$SCRIPT_DIR/themes/system.sh" list
                                echo
                                read -p "Enter theme name: " theme_name
                                if [[ -n "$theme_name" ]]; then
                                    bash "$SCRIPT_DIR/themes/system.sh" switch "$theme_name"
                                fi
                                ;;
                            *) echo -e "${YELLOW}Invalid option${NC}" ;;
                        esac
                    else
                        echo -e "${RED}❌ System theme manager not found${NC}"
                    fi
                    ;;
                2)
                    if [[ -f "$SCRIPT_DIR/themes/gtk.sh" ]]; then
                        echo
                        echo "GTK Theme Actions:"
                        echo "  1) Install themes"
                        echo "  2) List themes"
                        echo "  3) Set theme"
                        read -p "Action (1-3): " gtk_action
                        
                        case "$gtk_action" in
                            1) bash "$SCRIPT_DIR/themes/gtk.sh" install ;;
                            2) bash "$SCRIPT_DIR/themes/gtk.sh" list ;;
                            3) bash "$SCRIPT_DIR/themes/gtk.sh" select ;;
                            *) echo -e "${YELLOW}Invalid option${NC}" ;;
                        esac
                    else
                        echo -e "${RED}❌ GTK theme manager not found${NC}"
                    fi
                    ;;
                *) echo -e "${YELLOW}Invalid option${NC}" ;;
            esac
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
            show_status || echo -e "${RED}Error in status function${NC}"
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