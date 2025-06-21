#!/bin/bash
# Downloads and installs custom themes
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check for force flag
FORCE_REINSTALL=false
if [[ "$1" == "--force" ]]; then
    FORCE_REINSTALL=true
    echo -e "${YELLOW}🔄 Force reinstall mode enabled${NC}"
    echo
fi

# WhiteSur GTK Theme
echo "📥 Installing WhiteSur GTK theme..."
if [[ -d "$HOME/.themes/WhiteSur-Light" && "$FORCE_REINSTALL" != "true" ]]; then
    echo -e " ${GREEN}✓${NC} WhiteSur GTK theme already installed"
else
    if [[ "$FORCE_REINSTALL" == "true" && -d "$HOME/.themes/WhiteSur-Light" ]]; then
        echo " Removing existing GTK theme..."
        rm -rf "$HOME/.themes"/WhiteSur*
    fi
    echo " Downloading WhiteSur GTK theme..."
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    if git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git --depth=1; then
        cd WhiteSur-gtk-theme
        echo " Installing GTK theme..."
        if ./install.sh; then
            echo -e " ${GREEN}✓${NC} WhiteSur GTK theme installed successfully"
        else
            echo -e " ${RED}❌${NC} Failed to install WhiteSur GTK theme"
        fi
    else
        echo -e " ${RED}❌${NC} Failed to download WhiteSur GTK theme"
    fi
    # Cleanup
    rm -rf "$temp_dir"
fi
echo

# WhiteSur Icon Theme
echo "📥 Installing WhiteSur icon theme..."
if [[ ( -d "$HOME/.icons/WhiteSur" || -d "$HOME/.local/share/icons/WhiteSur" ) && "$FORCE_REINSTALL" != "true" ]]; then
    echo -e " ${GREEN}✓${NC} WhiteSur icon theme already installed"
else
    if [[ "$FORCE_REINSTALL" == "true" ]]; then
        echo " Removing existing icon theme..."
        rm -rf "$HOME/.icons"/WhiteSur* "$HOME/.local/share/icons"/WhiteSur*
    fi
    echo " Downloading WhiteSur icon theme..."
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    if git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git --depth=1; then
        cd WhiteSur-icon-theme
        echo " Installing icon theme with alternative icons..."
        if ./install.sh -a; then
            echo -e " ${GREEN}✓${NC} WhiteSur icon theme with alternative icons installed successfully"
        else
            echo -e " ${RED}❌${NC} Failed to install WhiteSur icon theme"
        fi
    else
        echo -e " ${RED}❌${NC} Failed to download WhiteSur icon theme"
    fi
    # Cleanup
    rm -rf "$temp_dir"
fi
echo

# WhiteSur Cursor Theme
echo "📥 Installing WhiteSur cursor theme..."
if [[ ( -d "$HOME/.icons/WhiteSur-cursors" || -d "$HOME/.local/share/icons/WhiteSur-cursors" ) && "$FORCE_REINSTALL" != "true" ]]; then
    echo -e " ${GREEN}✓${NC} WhiteSur cursor theme already installed"
else
    if [[ "$FORCE_REINSTALL" == "true" ]]; then
        echo " Removing existing cursor theme..."
        rm -rf "$HOME/.icons"/WhiteSur-cursors* "$HOME/.local/share/icons"/WhiteSur-cursors*
    fi
    echo " Downloading WhiteSur cursor theme..."
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    if git clone https://github.com/vinceliuice/WhiteSur-cursors.git --depth=1; then
        cd WhiteSur-cursors
        echo " Installing cursor theme..."
        if ./install.sh; then
            echo -e " ${GREEN}✓${NC} WhiteSur cursor theme installed successfully"
        else
            echo -e " ${RED}❌${NC} Failed to install WhiteSur cursor theme"
        fi
    else
        echo -e " ${RED}❌${NC} Failed to download WhiteSur cursor theme"
    fi
    # Cleanup
    rm -rf "$temp_dir"
fi
echo

echo -e "${YELLOW}💡 Note:${NC} After installing themes, you may need to:"
echo " • Restart your desktop environment"
echo " • Apply the GTK theme using your settings app"
echo " • Apply the icon theme using your settings app"
echo " • Log out and back in for full effect"
echo " • Run 'hyprctl reload' to reload Hyprland config"

echo
echo -e "${BLUE}🔍 Verifying cursor theme installation...${NC}"

# Check cursor theme installation
if [[ -d "$HOME/.icons/WhiteSur-cursors" ]]; then
    echo -e " ${GREEN}✓${NC} Cursor theme found in ~/.icons/WhiteSur-cursors"
elif [[ -d "$HOME/.local/share/icons/WhiteSur-cursors" ]]; then
    echo -e " ${GREEN}✓${NC} Cursor theme found in ~/.local/share/icons/WhiteSur-cursors"
else
    echo -e " ${RED}❌${NC} Cursor theme not found! Manual installation may be needed."
fi

echo
echo -e "${BLUE}🔧 Configuring WhiteSur themes in Hyprland...${NC}"

# Check if we have access to Hyprland config through dotfiles
HYPR_ENV_FILE="$HOME/dotfiles/stow/hypr/.config/hypr/env.conf"

if [[ -f "$HYPR_ENV_FILE" ]]; then
    theme_updated=false
    
    # Check and add GTK theme configuration
    if grep -q "GTK_THEME,WhiteSur" "$HYPR_ENV_FILE"; then
        echo -e " ${GREEN}✓${NC} GTK theme already configured in Hyprland"
    else
        echo " Adding GTK theme to Hyprland config..."
        
        if ! $theme_updated; then
            echo "" >> "$HYPR_ENV_FILE"
            echo "# WhiteSur themes (auto-added by dotfiles)" >> "$HYPR_ENV_FILE"
            theme_updated=true
        fi
        
        echo "env = GTK_THEME,WhiteSur-Dark" >> "$HYPR_ENV_FILE"
        echo "env = GTK4_THEME,WhiteSur-Dark" >> "$HYPR_ENV_FILE"
        
        echo -e " ${GREEN}✓${NC} GTK theme configuration added to Hyprland"
    fi
    
    # Check and add cursor theme configuration
    if grep -q "XCURSOR_THEME,WhiteSur-cursors" "$HYPR_ENV_FILE"; then
        echo -e " ${GREEN}✓${NC} Cursor theme already configured in Hyprland"
    else
        echo " Adding cursor theme to Hyprland config..."
        
        if ! $theme_updated; then
            echo "" >> "$HYPR_ENV_FILE"
            echo "# WhiteSur themes (auto-added by dotfiles)" >> "$HYPR_ENV_FILE"
            theme_updated=true
        fi
        
        echo "env = XCURSOR_THEME,WhiteSur-cursors" >> "$HYPR_ENV_FILE"
        echo "env = XCURSOR_SIZE,24" >> "$HYPR_ENV_FILE"
        echo "env = HYPRCURSOR_SIZE,24" >> "$HYPR_ENV_FILE"
        
        echo -e " ${GREEN}✓${NC} Cursor theme configuration added to Hyprland"
    fi
    
    echo
    echo -e "${YELLOW}🔄 To apply all themes:${NC}"
    echo " Run: hyprctl reload"
    echo " If still not working, logout and login again"
else
    echo -e " ${YELLOW}⚠️${NC} Hyprland config not found in dotfiles"
    echo
    echo -e "${YELLOW}🎨 Manual setup needed:${NC}"
    echo " 1. Add to your Hyprland env.conf:"
    echo "    env = GTK_THEME,WhiteSur-Dark"
    echo "    env = GTK4_THEME,WhiteSur-Dark"
    echo "    env = XCURSOR_THEME,WhiteSur-cursors"
    echo "    env = XCURSOR_SIZE,24"
    echo " 2. Run: hyprctl reload"
fi