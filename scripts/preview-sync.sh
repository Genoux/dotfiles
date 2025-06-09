#!/bin/bash

# Shows what packages would be installed/removed without doing anything

echo "🔍 Previewing sync changes..."

if [[ ! -f "packages.txt" || ! -f "aur-packages.txt" ]]; then
    echo "❌ Package files not found!"
    exit 1
fi

# Get current packages
current_official=($(pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}'))
current_aur=($(pacman -Qm | awk '{print $1}'))

# Get wanted packages
wanted_official=($(cat packages.txt))
wanted_aur=($(cat aur-packages.txt))

# Essential packages that should NEVER be removed
essential_packages=("base" "linux" "linux-firmware" "sudo" "systemd" "pacman" "bash")

echo "📊 Current vs Wanted:"
echo "  Current official: ${#current_official[@]}"
echo "  Wanted official: ${#wanted_official[@]}"
echo "  Current AUR: ${#current_aur[@]}"
echo "  Wanted AUR: ${#wanted_aur[@]}"

# Find packages to install
echo
echo "📦 PACKAGES TO INSTALL:"
missing_official=()
for pkg in "${wanted_official[@]}"; do
    if [[ ! " ${current_official[@]} " =~ " ${pkg} " ]]; then
        missing_official+=("$pkg")
    fi
done

missing_aur=()
for pkg in "${wanted_aur[@]}"; do
    if [[ ! " ${current_aur[@]} " =~ " ${pkg} " ]]; then
        missing_aur+=("$pkg")
    fi
done

if [[ ${#missing_official[@]} -gt 0 ]]; then
    echo "Official (${#missing_official[@]}):"
    printf '  %s\n' "${missing_official[@]}"
fi
if [[ ${#missing_aur[@]} -gt 0 ]]; then
    echo "AUR (${#missing_aur[@]}):"
    printf '  %s\n' "${missing_aur[@]}"
fi

# Find packages to remove
echo
echo "🗑️  PACKAGES TO REMOVE:"
to_remove_official=()
for pkg in "${current_official[@]}"; do
    if [[ ! " ${wanted_official[@]} " =~ " ${pkg} " ]]; then
        if [[ ! " ${essential_packages[@]} " =~ " ${pkg} " ]]; then
            to_remove_official+=("$pkg")
        fi
    fi
done

to_remove_aur=()
for pkg in "${current_aur[@]}"; do
    if [[ ! " ${wanted_aur[@]} " =~ " ${pkg} " ]]; then
        to_remove_aur+=("$pkg")
    fi
done

if [[ ${#to_remove_official[@]} -gt 0 ]]; then
    echo "Official (${#to_remove_official[@]}):"
    printf '  %s\n' "${to_remove_official[@]}"
fi
if [[ ${#to_remove_aur[@]} -gt 0 ]]; then
    echo "AUR (${#to_remove_aur[@]}):"
    printf '  %s\n' "${to_remove_aur[@]}"
fi

if [[ ${#missing_official[@]} -eq 0 && ${#missing_aur[@]} -eq 0 && ${#to_remove_official[@]} -eq 0 && ${#to_remove_aur[@]} -eq 0 ]]; then
    echo "✅ System is already in perfect sync!"
fi

echo
echo "💡 To apply these changes:"
echo "  Normal install: ./install-packages.sh"
echo "  Sync install:   ./install-packages.sh --sync"
