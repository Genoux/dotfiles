#!/bin/bash
# Downloads and installs custom themes

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🎨 Installing custom themes...${NC}"
echo

# WhiteSur GTK Theme
echo "📥 Installing WhiteSur GTK theme..."
if [[ -d "$HOME/.themes/WhiteSur-Light" ]]; then
    echo -e "   ${GREEN}✓${NC} WhiteSur GTK theme already installed"
else
    echo "   Downloading WhiteSur GTK theme..."
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    if git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git --depth=1; then
        cd WhiteSur-gtk-theme
        echo "   Installing GTK theme..."
        if ./install.sh; then
            echo -e "   ${GREEN}✓${NC} WhiteSur GTK theme installed successfully"
        else
            echo -e "   ${RED}❌${NC} Failed to install WhiteSur GTK theme"
        fi
    else
        echo -e "   ${RED}❌${NC} Failed to download WhiteSur GTK theme"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
fi

echo

# WhiteSur Icon Theme  
echo "📥 Installing WhiteSur icon theme..."
if [[ -d "$HOME/.icons/WhiteSur" || -d "$HOME/.local/share/icons/WhiteSur" ]]; then
    echo -e "   ${GREEN}✓${NC} WhiteSur icon theme already installed"
else
    echo "   Downloading WhiteSur icon theme..."
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    if git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git --depth=1; then
        cd WhiteSur-icon-theme
        echo "   Installing icon theme..."
        if ./install.sh; then
            echo -e "   ${GREEN}✓${NC} WhiteSur icon theme installed successfully"
        else
            echo -e "   ${RED}❌${NC} Failed to install WhiteSur icon theme"
        fi
    else
        echo -e "   ${RED}❌${NC} Failed to download WhiteSur icon theme"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
fi

echo
echo -e "${YELLOW}💡 Note:${NC} After installing themes, you may need to:"
echo "   • Restart your desktop environment" 
echo "   • Apply the GTK theme using your settings app"
echo "   • Apply the icon theme using your settings app"
echo "   • Log out and back in for full effect"