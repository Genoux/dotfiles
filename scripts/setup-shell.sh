#!/bin/bash

# setup-shell.sh - Complete shell setup (zsh, Oh My Zsh, plugins)
# Internal worker script - called by dotfiles.sh to set up complete shell environment

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

# Simple flag parsing
FORCE=false
QUIET=false

for arg in "$@"; do
    case $arg in
        --force) FORCE=true ;;
        --quiet) QUIET=true ;;
    esac
done

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
        echo -e "${GREEN}✅ Oh My Zsh already installed${NC}"
        return 0
    fi
    
    if [[ "$omz_status" == "installed" && "$FORCE" == true ]]; then
        echo -e "${YELLOW}🔄 Reinstalling Oh My Zsh...${NC}"
        rm -rf "$HOME/.oh-my-zsh"
    fi
    
    echo -e "${BLUE}📦 Installing Oh My Zsh...${NC}"
    echo -e "   📥 Downloading installer..."
    
    # Download and run installer
    local temp_file=$(mktemp)
    if curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh > "$temp_file"; then
        echo -e "   🚀 Running installer..."
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

# Read plugins from file
read_plugins_file() {
    local plugins_file="$DOTFILES_DIR/zsh-plugins.txt"
    
    if [[ ! -f "$plugins_file" ]]; then
        echo -e "${RED}❌ Plugin list not found: $plugins_file${NC}"
        echo -e "${BLUE}💡 Create the file with format: plugin-name:repository-url${NC}"
        return 1
    fi
    
    # Read non-comment, non-empty lines
    grep -v '^#' "$plugins_file" | grep -v '^[[:space:]]*$'
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
    
    # Read plugins from file
    local plugin_list
    if ! plugin_list=$(read_plugins_file); then
        return 1
    fi
    
    if [[ -z "$plugin_list" ]]; then
        echo -e "${YELLOW}⚠️  No plugins found in zsh-plugins.txt${NC}"
        return 0
    fi
    
    local plugin_count=$(echo "$plugin_list" | wc -l)
    echo -e "${BLUE}📋 Found $plugin_count plugins to process...${NC}"
    
    local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
    mkdir -p "$plugins_dir"
    
    # Process each plugin line
    local processed_count=0
    while IFS= read -r plugin_info; do
        [[ -z "$plugin_info" ]] && continue
        
        local plugin_name=$(echo "$plugin_info" | cut -d':' -f1)
        local plugin_url=$(echo "$plugin_info" | cut -d':' -f2-)
        local plugin_dir="$plugins_dir/$plugin_name"
        
        processed_count=$((processed_count + 1))
        echo -e "${BLUE}Processing plugin $processed_count/$plugin_count: $plugin_name${NC}"
        
        local status=$(check_plugin_status "$plugin_name")
        
        if [[ "$status" == "installed" && "$FORCE" != true ]]; then
            echo -e "  ${GREEN}✅${NC} $plugin_name already installed"
            continue
        fi
        
        if [[ "$status" == "installed" && "$FORCE" == true ]]; then
            echo -e "  ${YELLOW}🔄${NC} Reinstalling $plugin_name..."
            rm -rf "$plugin_dir"
        fi
        
        echo -e "  ${BLUE}📦${NC} Installing $plugin_name from $plugin_url..."
        if timeout 30 git clone "$plugin_url" "$plugin_dir" --depth=1 2>&1; then
            echo -e "  ${GREEN}✅${NC} $plugin_name installed successfully"
        else
            echo -e "  ${RED}❌${NC} Failed to install $plugin_name"
            echo -e "      ${RED}Error details: Clone failed or timed out for $plugin_url${NC}"
        fi
    done <<< "$plugin_list"
    
    echo -e "${GREEN}✅ Plugin installation complete! ($plugin_count plugins processed)${NC}"
}

# Set zsh as default shell
set_default_shell() {
    local current_shell=$(getent passwd "$USER" | cut -d: -f7)
    local zsh_path=$(which zsh)
    
    if [[ "$current_shell" == "$zsh_path" ]]; then
        echo -e "${GREEN}✅ zsh is already the default shell${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🔧 Setting zsh as default shell...${NC}"
    
    # Always show password prompt clearly, even in quiet mode
    echo -e "${YELLOW}🔐 Password required to change default shell${NC}"
    echo -e "${BLUE}💡 Running: chsh -s $zsh_path${NC}"
    
    if chsh -s "$zsh_path"; then
        echo -e "${GREEN}✅ Default shell changed to zsh${NC}"
        echo -e "${YELLOW}💡 Log out and back in for changes to take effect${NC}"
    else
        echo -e "${RED}❌ Failed to change default shell${NC}"
        echo -e "${BLUE}💡 You can manually run: chsh -s $zsh_path${NC}"
        echo -e "${YELLOW}   (This is optional - shell config will work anyway)${NC}"
        return 1
    fi
}

# Process shell config template (auto-sync plugins)
process_shell_template() {
    local master_template="$DOTFILES_DIR/stow/shell/.zshrc.template"
    local target_file="$DOTFILES_DIR/stow/shell/.zshrc"
    local temp_file=$(mktemp)
    
    if [[ "$QUIET" != true ]]; then
        echo -e "${BLUE}🔄 Auto-syncing .zshrc with plugins from zsh-plugins.txt...${NC}"
    fi
    
    # Always start from master template to preserve placeholders
    if [[ ! -f "$master_template" ]]; then
        echo -e "${RED}❌ Master template not found: $master_template${NC}"
        return 1
    fi
    
    # Read external plugins from zsh-plugins.txt
    local external_plugins=()
    local external_plugins_list=""
    
    local plugin_list
    if plugin_list=$(read_plugins_file 2>/dev/null); then
        while IFS= read -r plugin_line; do
            [[ -z "$plugin_line" ]] && continue
            local plugin_name=$(echo "$plugin_line" | cut -d':' -f1)
            external_plugins+=("$plugin_name")
        done <<< "$plugin_list"
        
        if [[ ${#external_plugins[@]} -gt 0 ]]; then
            external_plugins_list=$(IFS=', '; echo "${external_plugins[*]}")
            # Create plugin array entries (properly indented)
            local plugin_array=""
            for plugin in "${external_plugins[@]}"; do
                plugin_array="${plugin_array}  ${plugin}"$'\n'
            done
            # Remove trailing newline
            plugin_array=$(echo -n "$plugin_array" | sed '$s/$//')
        fi
    fi
    
    # Process master template and replace placeholders
    # Simple line-by-line processing from master template
    while IFS= read -r line; do
        if [[ "$line" == *"{{EXTERNAL_PLUGINS}}"* ]]; then
            echo "${line//\{\{EXTERNAL_PLUGINS\}\}/$external_plugins_list}" >> "$temp_file"
        elif [[ "$line" == *"{{EXTERNAL_PLUGINS_ARRAY}}"* ]]; then
            # Replace with external plugins, each on its own line
            if [[ -n "$plugin_array" ]]; then
                echo "$plugin_array" >> "$temp_file"
            fi
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$master_template"
    
    # Replace target file with processed version (master template stays intact)
    mv "$temp_file" "$target_file"
    echo -e "${GREEN}✅ .zshrc synced with ${#external_plugins[@]} external plugins${NC}"
}

# Main execution - complete shell setup
echo -e "${BLUE}🚀 Complete Shell Setup${NC}"
echo

# Check prerequisites
if ! check_zsh; then
    exit 1
fi

# Step 1: Install Oh My Zsh
echo -e "${BLUE}Step 1: Installing Oh My Zsh...${NC}"
if ! install_omz; then
    echo -e "${RED}❌ Failed to install Oh My Zsh${NC}"
    exit 1
fi
echo

# Step 2: Install plugins
echo -e "${BLUE}Step 2: Installing plugins...${NC}"
install_plugins
echo

# Step 3: Sync .zshrc template
echo -e "${BLUE}Step 3: Syncing .zshrc with plugin list...${NC}"
process_shell_template
echo

# Step 4: Set default shell
echo -e "${BLUE}Step 4: Setting default shell...${NC}"
if ! set_default_shell; then
    echo -e "${YELLOW}⚠️  Shell setup will continue (default shell change is optional)${NC}"
fi
echo

echo -e "${GREEN}🎉 Shell setup complete!${NC}" 