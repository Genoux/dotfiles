#!/bin/bash

# install-packages.sh
# Installs all packages from txt files. Use --sync to remove unlisted packages
# Enhanced with automatic dependency detection and addition

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Parse command line arguments
SYNC_MODE=false
if [[ "$1" == "--sync" ]]; then
    SYNC_MODE=true
    echo -e "${YELLOW}🔄 SYNC MODE: Will remove packages not in your lists!${NC}"
fi

echo -e "${BLUE}🚀 Installing packages from your lists...${NC}"

# Check if package files exist
if [[ ! -f "packages.txt" || ! -f "aur-packages.txt" ]]; then
    echo -e "${RED}❌ Package files not found! Run ./get-packages.sh first${NC}"
    exit 1
fi

echo -e "${BLUE}📊 Package lists:${NC}"
echo "  Official packages: $(wc -l < packages.txt)"
echo "  AUR packages: $(wc -l < aur-packages.txt)"

# Function to add package to appropriate list
add_to_list() {
    local pkg="$1"
    local reason="$2"
    
    # Check if package is from AUR
    if pacman -Qm "$pkg" &>/dev/null 2>&1; then
        # AUR package
        if ! grep -q "^$pkg$" aur-packages.txt; then
            echo "$pkg" >> aur-packages.txt
            echo -e "  ${PURPLE}📝 Added AUR:${NC} $pkg ($reason)"
            return 0
        fi
    else
        # Official package
        if ! grep -q "^$pkg$" packages.txt; then
            echo "$pkg" >> packages.txt
            echo -e "  ${BLUE}📝 Added Official:${NC} $pkg ($reason)"
            return 0
        fi
    fi
    return 1
}

# Function to find and add missing dependencies
find_missing_deps() {
    echo -e "${BLUE}🔍 Scanning for missing dependencies...${NC}"
    
    local added_any=false
    local listed_packages=""
    
    # Get all packages from our lists
    listed_packages="$(grep -v '^#\|^$' packages.txt aur-packages.txt 2>/dev/null | tr '\n' ' ')"
    
    # Check each listed package for missing dependencies
    for pkg in $listed_packages; do
        # Skip if package isn't installed
        if ! pacman -Qi "$pkg" &>/dev/null; then
            continue
        fi
        
        # Get dependencies (handle multi-line dependencies properly)
        local deps=$(pacman -Qi "$pkg" 2>/dev/null | awk '/^Depends On/ {found=1; gsub(/^Depends On\s*:\s*/, ""); line=$0} found && !/^[A-Z]/ {line=line $0} found && /^[A-Z]/ && !/^Depends On/ {found=0} END {if(found || line) print line}' | tr ' ' '\n' | grep -v '^$\|^None$' | sed 's/[>=<].*$//' | sort -u)
        
        for dep in $deps; do
            # Skip if dependency is virtual or not installed
            if [[ -z "$dep" ]] || ! pacman -Qi "$dep" &>/dev/null 2>&1; then
                continue
            fi
            
            # Check if dependency is in our lists  
            if ! echo "$listed_packages" | grep -q "\b$dep\b"; then
                if add_to_list "$dep" "dependency of $pkg"; then
                    added_any=true
                fi
            fi
        done
    done
    
    if $added_any; then
        echo -e "  ${GREEN}📋 Updated package lists with missing dependencies${NC}"
        # Sort and clean up the files
        sort -u packages.txt -o packages.txt
        sort -u aur-packages.txt -o aur-packages.txt
        echo -e "  ${GREEN}📝 Package lists sorted and cleaned${NC}"
    else
        echo -e "  ${GREEN}✅ No missing dependencies found${NC}"
    fi
    echo
}

# Step 1: Find and add missing dependencies first
find_missing_deps

# If sync mode, show what would be removed
if [[ "$SYNC_MODE" == true ]]; then
    echo -e "${BLUE}🔍 Checking for packages to remove...${NC}"
    
    # Get current packages
    current_official=($(pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}'))
    current_aur=($(pacman -Qm | awk '{print $1}'))
    
    # Get wanted packages (re-read after dependency additions)
    wanted_official=($(grep -v '^#\|^$' packages.txt))
    wanted_aur=($(grep -v '^#\|^$' aur-packages.txt))
    
    # Essential packages that should NEVER be removed
    essential_packages=(
        "base" "linux" "linux-firmware" "sudo" "systemd" "pacman"
        "bash" "coreutils" "util-linux" "glibc" "gcc" "binutils"
        "make" "fakeroot" "pkg-config" "which" "findutils" "grep"
        "gawk" "sed" "tar" "gzip"
    )
    
    # Find packages to remove (official)
    to_remove_official=()
    for pkg in "${current_official[@]}"; do
        if [[ ! " ${wanted_official[*]} " =~ " ${pkg} " ]]; then
            # Check if it's essential
            if [[ ! " ${essential_packages[*]} " =~ " ${pkg} " ]]; then
                to_remove_official+=("$pkg")
            fi
        fi
    done
    
    # Find AUR packages to remove
    to_remove_aur=()
    for pkg in "${current_aur[@]}"; do
        if [[ ! " ${wanted_aur[*]} " =~ " ${pkg} " ]]; then
            to_remove_aur+=("$pkg")
        fi
    done
    
    # Show what would be removed
    if [[ ${#to_remove_official[@]} -gt 0 || ${#to_remove_aur[@]} -gt 0 ]]; then
        echo
        echo -e "${YELLOW}⚠️  PACKAGES TO BE REMOVED:${NC}"
        if [[ ${#to_remove_official[@]} -gt 0 ]]; then
            echo -e "${BLUE}Official packages (${#to_remove_official[@]}):${NC}"
            printf '  %s\n' "${to_remove_official[@]}"
        fi
        if [[ ${#to_remove_aur[@]} -gt 0 ]]; then
            echo -e "${PURPLE}AUR packages (${#to_remove_aur[@]}):${NC}"
            printf '  %s\n' "${to_remove_aur[@]}"
        fi
        echo
        echo -e "${RED}❗ This will PERMANENTLY REMOVE these packages!${NC}"
        read -p "Continue with sync? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Sync cancelled. Will only install missing packages.${NC}"
            SYNC_MODE=false
        fi
    else
        echo -e "${GREEN}✅ No packages to remove - system is already in sync!${NC}"
    fi
fi

# Regular confirmation for install
echo
read -p "Continue with installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled.${NC}"
    exit 0
fi

# Update system first
echo -e "${BLUE}📦 Updating system...${NC}"
sudo pacman -Syu --noconfirm

# Install missing official packages (enhanced with batch install)
echo -e "${BLUE}📦 Installing missing official packages...${NC}"
missing_official=()
while read -r package; do
    # Skip comments and empty lines
    [[ "$package" =~ ^#.*$ ]] || [[ -z "$package" ]] && continue
    
    if ! pacman -Q "$package" &>/dev/null; then
        missing_official+=("$package")
    fi
done < packages.txt

if [[ ${#missing_official[@]} -gt 0 ]]; then
    echo -e "  ${YELLOW}Installing:${NC} ${missing_official[*]}"
    if sudo pacman -S --needed --noconfirm "${missing_official[@]}"; then
        echo -e "  ${GREEN}✅ Official packages installed successfully${NC}"
    else
        echo -e "  ${RED}⚠️  Some official packages failed to install${NC}"
    fi
else
    echo -e "  ${GREEN}✅ All official packages already installed${NC}"
fi

# Install yay if not present
if ! command -v yay &> /dev/null; then
    echo -e "${BLUE}📦 Installing yay (AUR helper)...${NC}"
    sudo pacman -S --needed --noconfirm base-devel git
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd - > /dev/null
fi

# Install missing AUR packages (enhanced with batch install)
if [[ -s "aur-packages.txt" ]]; then
    echo -e "${BLUE}📦 Installing missing AUR packages...${NC}"
    missing_aur=()
    while read -r package; do
        # Skip comments and empty lines
        [[ "$package" =~ ^#.*$ ]] || [[ -z "$package" ]] && continue
        
        if ! pacman -Q "$package" &>/dev/null; then
            missing_aur+=("$package")
        fi
    done < aur-packages.txt
    
    if [[ ${#missing_aur[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}Installing from AUR:${NC} ${missing_aur[*]}"
        if yay -S --needed --noconfirm "${missing_aur[@]}"; then
            echo -e "  ${GREEN}✅ AUR packages installed successfully${NC}"
        else
            echo -e "  ${RED}⚠️  Some AUR packages failed to install${NC}"
        fi
    else
        echo -e "  ${GREEN}✅ All AUR packages already installed${NC}"
    fi
fi

# Remove unwanted packages if in sync mode
if [[ "$SYNC_MODE" == true ]]; then
    if [[ ${#to_remove_official[@]} -gt 0 ]]; then
        echo -e "${BLUE}🗑️  Removing unwanted official packages...${NC}"
        if sudo pacman -Rns --noconfirm "${to_remove_official[@]}"; then
            echo -e "  ${GREEN}✅ Official packages removed successfully${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Some official packages couldn't be removed (likely due to dependencies)${NC}"
        fi
    fi
    
    if [[ ${#to_remove_aur[@]} -gt 0 ]]; then
        echo -e "${BLUE}🗑️  Removing unwanted AUR packages...${NC}"
        if sudo pacman -Rns --noconfirm "${to_remove_aur[@]}"; then
            echo -e "  ${GREEN}✅ AUR packages removed successfully${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Some AUR packages couldn't be removed (likely due to dependencies)${NC}"
        fi
    fi
fi

# Final dependency check after installation
echo -e "${BLUE}🔍 Final dependency scan...${NC}"
find_missing_deps

echo -e "${GREEN}✅ Installation complete!${NC}"

if [[ "$SYNC_MODE" == true ]]; then
    echo -e "${GREEN}🔄 System synced to your package lists!${NC}"
fi

echo
echo -e "${BLUE}📋 Final Summary:${NC}"
echo "  Official packages: $(wc -l < packages.txt)"
echo "  AUR packages: $(wc -l < aur-packages.txt)"
echo -e "  ${GREEN}All dependencies automatically maintained!${NC}"