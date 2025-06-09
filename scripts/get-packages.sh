#!/bin/bash

# Gets all installed packages and saves to txt files

echo "📦 Getting all packages from your current system..."

# Backup existing lists if they exist
if [[ -f "packages.txt" ]]; then
    mv packages.txt "packages.txt.backup.$(date +%Y%m%d_%H%M%S)"
    echo "📋 Backed up existing packages.txt"
fi

if [[ -f "aur-packages.txt" ]]; then
    mv aur-packages.txt "aur-packages.txt.backup.$(date +%Y%m%d_%H%M%S)"
    echo "📋 Backed up existing aur-packages.txt"
fi

# Get ALL explicitly installed official packages (excluding AUR)
echo "🔍 Scanning official packages..."
pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}' > packages.txt

# Get ALL AUR packages  
echo "🔍 Scanning AUR packages..."
pacman -Qm | awk '{print $1}' > aur-packages.txt

echo "✅ Package lists updated!"
echo
echo "📊 Summary:"
echo "  Official packages: $(wc -l < packages.txt)"
echo "  AUR packages: $(wc -l < aur-packages.txt)"
echo "  Total packages: $(($(wc -l < packages.txt) + $(wc -l < aur-packages.txt)))"

echo
echo "📁 Files created/updated:"
echo "  - packages.txt"
echo "  - aur-packages.txt"

echo
echo "🔍 Sample packages:"
echo "Official (first 5):"
head -5 packages.txt
echo "AUR (first 5):"
head -5 aur-packages.txt

echo
echo "💡 Next step: Run ./install-packages.sh on a new machine"
