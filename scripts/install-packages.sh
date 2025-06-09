#!/bin/bash

# Installs all packages from txt files. Use --sync to remove unlisted packages

set -e

# Parse command line arguments
SYNC_MODE=false
if [[ "$1" == "--sync" ]]; then
    SYNC_MODE=true
    echo "🔄 SYNC MODE: Will remove packages not in your lists!"
fi

echo "🚀 Installing packages from your lists..."

# Check if package files exist
if [[ ! -f "packages.txt" || ! -f "aur-packages.txt" ]]; then
    echo "❌ Package files not found! Run ./get-packages.sh first"
    exit 1
fi

echo "📊 Package lists:"
echo "  Official packages: $(wc -l < packages.txt)"
echo "  AUR packages: $(wc -l < aur-packages.txt)"

# If sync mode, show what would be removed
if [[ "$SYNC_MODE" == true ]]; then
    echo
    echo "🔍 Checking for packages to remove..."
    
    # Get current packages
    current_official=($(pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}'))
    current_aur=($(pacman -Qm | awk '{print $1}'))
    
    # Get wanted packages
    wanted_official=($(cat packages.txt))
    wanted_aur=($(cat aur-packages.txt))
    
    # Essential packages that should NEVER be removed
    essential_packages=(
        "base"
        "linux" 
        "linux-firmware"
        "sudo"
        "systemd"
        "pacman"
        "bash"
        "coreutils"
        "util-linux"
        "glibc"
    )
    
    # Find packages to remove (official)
    to_remove_official=()
    for pkg in "${current_official[@]}"; do
        if [[ ! " ${wanted_official[@]} " =~ " ${pkg} " ]]; then
            # Check if it's essential
            if [[ ! " ${essential_packages[@]} " =~ " ${pkg} " ]]; then
                to_remove_official+=("$pkg")
            fi
        fi
    done
    
    # Find AUR packages to remove
    to_remove_aur=()
    for pkg in "${current_aur[@]}"; do
        if [[ ! " ${wanted_aur[@]} " =~ " ${pkg} " ]]; then
            to_remove_aur+=("$pkg")
        fi
    done
    
    # Show what would be removed
    if [[ ${#to_remove_official[@]} -gt 0 || ${#to_remove_aur[@]} -gt 0 ]]; then
        echo
        echo "⚠️  PACKAGES TO BE REMOVED:"
        if [[ ${#to_remove_official[@]} -gt 0 ]]; then
            echo "Official packages (${#to_remove_official[@]}):"
            printf '  %s\n' "${to_remove_official[@]}"
        fi
        if [[ ${#to_remove_aur[@]} -gt 0 ]]; then
            echo "AUR packages (${#to_remove_aur[@]}):"
            printf '  %s\n' "${to_remove_aur[@]}"
        fi
        echo
        echo "❗ This will PERMANENTLY REMOVE these packages!"
        read -p "Continue with sync? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Sync cancelled. Will only install missing packages."
            SYNC_MODE=false
        fi
    else
        echo "✅ No packages to remove - system is already in sync!"
    fi
fi

# Regular confirmation for install
echo
read -p "Continue with installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Update system first
echo "📦 Updating system..."
sudo pacman -Syu --noconfirm

# Install missing official packages
echo "📦 Installing missing official packages..."
while read -r package; do
    if [[ ! -z "$package" ]]; then
        if ! pacman -Q "$package" &>/dev/null; then
            echo "Installing: $package"
            sudo pacman -S --needed --noconfirm "$package" || echo "⚠️  Failed to install $package"
        fi
    fi
done < packages.txt

# Install yay if not present
if ! command -v yay &> /dev/null; then
    echo "📦 Installing yay (AUR helper)..."
    sudo pacman -S --needed --noconfirm base-devel git
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd - > /dev/null
fi

# Install missing AUR packages
if [[ -s "aur-packages.txt" ]]; then
    echo "📦 Installing missing AUR packages..."
    while read -r package; do
        if [[ ! -z "$package" ]]; then
            if ! pacman -Q "$package" &>/dev/null; then
                echo "Installing from AUR: $package"
                yay -S --needed --noconfirm "$package" || echo "⚠️  Failed to install $package"
            fi
        fi
    done < aur-packages.txt
fi

# Remove unwanted packages if in sync mode
if [[ "$SYNC_MODE" == true ]]; then
    if [[ ${#to_remove_official[@]} -gt 0 ]]; then
        echo "🗑️  Removing unwanted official packages..."
        sudo pacman -Rns --noconfirm "${to_remove_official[@]}" || echo "⚠️  Some packages couldn't be removed"
    fi
    
    if [[ ${#to_remove_aur[@]} -gt 0 ]]; then
        echo "🗑️  Removing unwanted AUR packages..."
        sudo pacman -Rns --noconfirm "${to_remove_aur[@]}" || echo "⚠️  Some packages couldn't be removed"
    fi
fi

echo "✅ Installation complete!"

if [[ "$SYNC_MODE" == true ]]; then
    echo "🔄 System synced to your package lists!"
fi
