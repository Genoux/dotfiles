#!/bin/bash

# setup-shell.sh - Complete shell setup (zsh, Oh My Zsh, plugins)
# Handles shell extensions installation automatically

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

show_help() {
    echo -e "${BLUE}🐚 Shell Setup Manager${NC}"
    echo
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo -e "  ${GREEN}install${NC}     Complete shell setup (default)"
    echo -e "  ${GREEN}omz${NC}         Install Oh My Zsh only"
    echo -e "  ${GREEN}plugins${NC}     Install zsh plugins only"
    echo -e "  ${GREEN}status${NC}      Check installation status"
    echo
    echo "Options:"
    echo "  --force       Skip confirmations and reinstall"
    echo "  --quiet       Minimal output"
    echo
    echo "Examples:"
    echo -e "  ${GREEN}$0${NC}                   # Complete shell setup"
    echo -e "  ${GREEN}$0 install --force${NC}  # Force reinstall everything"
    echo -e "  ${GREEN}$0 plugins${NC}          # Just install plugins"
}

# Parse arguments
COMMAND=""
FORCE=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        install|omz|plugins|status)
            COMMAND="$1"
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Default to install if no command given
if [[ -z "$COMMAND" ]]; then
    COMMAND="install"
fi

# Check if zsh is installed
check_zsh() {
    if ! command -v zsh &> /dev/null; then
        echo -e "${RED}❌ zsh is not installed${NC}"
        echo -e "${BLUE}💡 Install zsh first: Add 'zsh' to packages.txt and run package sync${NC}"
        return 1
    fi
    return 0
}

# Check Oh My Zsh installation status
check_omz_status() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        echo "installed"
    else
        echo "missing"
    fi
}

# Install Oh My Zsh
install_omz() {
    local omz_status=$(check_omz_status)
    
    if [[ "$omz_status" == "installed" && "$FORCE" != true ]]; then
        [[ "$QUIET" != true ]] && echo -e "${GREEN}✅ Oh My Zsh already installed${NC}"
        return 0
    fi
    
    if [[ "$omz_status" == "installed" && "$FORCE" == true ]]; then
        echo -e "${YELLOW}🔄 Reinstalling Oh My Zsh...${NC}"
        rm -rf "$HOME/.oh-my-zsh"
    fi
    
    echo -e "${BLUE}📦 Installing Oh My Zsh...${NC}"
    
    # Download and run installer
    local temp_file=$(mktemp)
    if curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh > "$temp_file"; then
        # Run installer in unattended mode
        env RUNZSH=no CHSH=no sh "$temp_file"
        
        if [[ -d "$HOME/.oh-my-zsh" ]]; then
            echo -e "${GREEN}✅ Oh My Zsh installed successfully${NC}"
        else
            echo -e "${RED}❌ Oh My Zsh installation failed${NC}"
            rm -f "$temp_file"
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to download Oh My Zsh installer${NC}"
        rm -f "$temp_file"
        return 1
    fi
    
    rm -f "$temp_file"
    return 0
}

# Check plugin installation status
check_plugin_status() {
    local plugin="$1"
    local plugin_dir="$HOME/.oh-my-zsh/custom/plugins/$plugin"
    
    if [[ -d "$plugin_dir" ]]; then
        echo "installed"
    else
        echo "missing"
    fi
}

# Install zsh plugins
install_plugins() {
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        echo -e "${RED}❌ Oh My Zsh not installed. Install it first.${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔌 Installing zsh plugins...${NC}"
    
    # Define plugins to install (based on .zshrc config)
    local plugins=(
        "zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions.git"
        "zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting.git"
    )
    
    local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
    mkdir -p "$plugins_dir"
    
    for plugin_info in "${plugins[@]}"; do
        local plugin_name=$(echo "$plugin_info" | cut -d':' -f1)
        local plugin_url=$(echo "$plugin_info" | cut -d':' -f2)
        local plugin_dir="$plugins_dir/$plugin_name"
        
        local status=$(check_plugin_status "$plugin_name")
        
        if [[ "$status" == "installed" && "$FORCE" != true ]]; then
            [[ "$QUIET" != true ]] && echo -e "  ${GREEN}✅${NC} $plugin_name already installed"
            continue
        fi
        
        if [[ "$status" == "installed" && "$FORCE" == true ]]; then
            echo -e "  ${YELLOW}🔄${NC} Reinstalling $plugin_name..."
            rm -rf "$plugin_dir"
        fi
        
        echo -e "  ${BLUE}📦${NC} Installing $plugin_name..."
        if git clone "$plugin_url" "$plugin_dir" --depth=1; then
            echo -e "  ${GREEN}✅${NC} $plugin_name installed successfully"
        else
            echo -e "  ${RED}❌${NC} Failed to install $plugin_name"
        fi
    done
}

# Set zsh as default shell
set_default_shell() {
    local current_shell=$(getent passwd "$USER" | cut -d: -f7)
    local zsh_path=$(which zsh)
    
    if [[ "$current_shell" == "$zsh_path" ]]; then
        [[ "$QUIET" != true ]] && echo -e "${GREEN}✅ zsh is already the default shell${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🔧 Setting zsh as default shell...${NC}"
    
    if chsh -s "$zsh_path"; then
        echo -e "${GREEN}✅ Default shell changed to zsh${NC}"
        echo -e "${YELLOW}💡 Log out and back in for changes to take effect${NC}"
    else
        echo -e "${RED}❌ Failed to change default shell${NC}"
        echo -e "${BLUE}💡 You can manually run: chsh -s $zsh_path${NC}"
        return 1
    fi
}

# Command functions
cmd_status() {
    echo -e "${BLUE}🐚 Shell Setup Status${NC}"
    echo
    
    # Check zsh
    if command -v zsh &> /dev/null; then
        echo -e "${GREEN}✅ zsh:${NC} $(zsh --version | cut -d' ' -f2)"
    else
        echo -e "${RED}❌ zsh:${NC} Not installed"
    fi
    
    # Check Oh My Zsh
    local omz_status=$(check_omz_status)
    if [[ "$omz_status" == "installed" ]]; then
        local omz_version=""
        if [[ -f "$HOME/.oh-my-zsh/tools/upgrade.sh" ]]; then
            omz_version="$(cd "$HOME/.oh-my-zsh" && git describe --tags 2>/dev/null || echo "unknown")"
        fi
        echo -e "${GREEN}✅ Oh My Zsh:${NC} Installed${omz_version:+ ($omz_version)}"
    else
        echo -e "${RED}❌ Oh My Zsh:${NC} Not installed"
    fi
    
    # Check plugins
    echo
    echo -e "${BLUE}🔌 Plugin Status:${NC}"
    local plugins=("zsh-autosuggestions" "zsh-syntax-highlighting")
    
    for plugin in "${plugins[@]}"; do
        local status=$(check_plugin_status "$plugin")
        if [[ "$status" == "installed" ]]; then
            echo -e "  ${GREEN}✅${NC} $plugin"
        else
            echo -e "  ${RED}❌${NC} $plugin"
        fi
    done
    
    # Check default shell
    echo
    local current_shell=$(getent passwd "$USER" | cut -d: -f7)
    local zsh_path=$(which zsh 2>/dev/null || echo "")
    
    if [[ "$current_shell" == "$zsh_path" && -n "$zsh_path" ]]; then
        echo -e "${GREEN}✅ Default shell:${NC} zsh"
    else
        echo -e "${YELLOW}⚠️  Default shell:${NC} $current_shell (not zsh)"
    fi
}

cmd_install() {
    echo -e "${BLUE}🚀 Complete Shell Setup${NC}"
    echo
    
    # Check prerequisites
    if ! check_zsh; then
        return 1
    fi
    
    # Step 1: Install Oh My Zsh
    echo -e "${BLUE}Step 1: Installing Oh My Zsh...${NC}"
    if ! install_omz; then
        echo -e "${RED}❌ Failed to install Oh My Zsh${NC}"
        return 1
    fi
    echo
    
    # Step 2: Install plugins
    echo -e "${BLUE}Step 2: Installing plugins...${NC}"
    install_plugins
    echo
    
    # Step 3: Set default shell
    echo -e "${BLUE}Step 3: Setting default shell...${NC}"
    set_default_shell
    echo
    
    echo -e "${GREEN}🎉 Shell setup complete!${NC}"
    echo
    echo -e "${YELLOW}📋 Next steps:${NC}"
    echo "  • Install shell configs: dotfiles.sh → Install Config → shell"
    echo "  • Log out and back in for shell changes"
    echo "  • Open new terminal to see Oh My Zsh in action"
}

cmd_omz() {
    echo -e "${BLUE}📦 Installing Oh My Zsh Only${NC}"
    echo
    
    if ! check_zsh; then
        return 1
    fi
    
    install_omz
}

cmd_plugins() {
    echo -e "${BLUE}🔌 Installing Plugins Only${NC}"
    echo
    
    install_plugins
}

# Execute command
case "$COMMAND" in
    install)
        cmd_install
        ;;
    omz)
        cmd_omz
        ;;
    plugins)
        cmd_plugins
        ;;
    status)
        cmd_status
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac 