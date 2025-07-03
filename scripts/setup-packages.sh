#!/bin/bash

# setup-packages.sh - Package management for dotfiles
# Handles getting, installing, and syncing packages only

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

# Simple argument parsing
COMMAND=""
FORCE=false
NO_DEPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        get|install|check)
            COMMAND="$1"
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --no-deps)
            NO_DEPS=true
            shift
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Default to smart install if no command given
if [[ -z "$COMMAND" ]]; then
    COMMAND="install"
fi

# Change to dotfiles directory
cd "$DOTFILES_DIR"

# Hardware detection functions
detect_gpu() {
    local has_nvidia=false
    local has_amd=false
    local has_intel=false
    
    # Check for NVIDIA
    if lspci | grep -i nvidia &>/dev/null || lsmod | grep -i nvidia &>/dev/null; then
        has_nvidia=true
    fi
    
    # Check for AMD
    if lspci | grep -i "vga.*amd\|vga.*ati\|display.*amd\|display.*ati" &>/dev/null; then
        has_amd=true
    fi
    
    # Check for Intel
    if lspci | grep -i "vga.*intel\|display.*intel" &>/dev/null; then
        has_intel=true
    fi
    
    echo "nvidia:$has_nvidia,amd:$has_amd,intel:$has_intel"
}

# Hardware-specific package filtering
filter_packages_by_hardware() {
    local package_file="$1"
    local temp_file=$(mktemp)
    local show_status="$2"  # Optional parameter to show status
    
    # Get GPU info
    local gpu_info=$(detect_gpu)
    local has_nvidia=$(echo "$gpu_info" | grep -o 'nvidia:[^,]*' | cut -d: -f2)
    
    # NVIDIA-specific packages to filter
    local nvidia_packages=(
        "nvidia"
        "nvidia-prime" 
        "nvidia-settings"
        "nvidia-utils"
        "python-nvidia-ml-py"
    )
    
    if [[ "$has_nvidia" == "true" ]]; then
        # Keep all packages if NVIDIA is present
        cp "$package_file" "$temp_file"
        if [[ "$show_status" == "true" ]]; then
            echo -e "${GREEN}🖥️  NVIDIA GPU detected - keeping NVIDIA packages${NC}" >&2
        fi
    else
        # Filter out NVIDIA packages if no NVIDIA hardware
        if [[ "$show_status" == "true" ]]; then
            echo -e "${YELLOW}🖥️  No NVIDIA GPU detected - filtering NVIDIA packages${NC}" >&2
        fi
        while IFS= read -r line; do
            local should_keep=true
            for nvidia_pkg in "${nvidia_packages[@]}"; do
                if [[ "$line" == "$nvidia_pkg" ]]; then
                    should_keep=false
                    if [[ "$show_status" == "true" ]]; then
                        echo -e "  ${YELLOW}⏭️  Skipping: $nvidia_pkg (no NVIDIA hardware)${NC}" >&2
                    fi
                    break
                fi
            done
            if $should_keep && [[ "$line" =~ ^[^#] ]] && [[ -n "$line" ]]; then
                echo "$line" >> "$temp_file"
            fi
        done < "$package_file"
    fi
    
    # Only echo the temp file path (this is what gets captured)
    echo "$temp_file"
}

# Essential packages that should NEVER be removed
essential_packages=(
    "base" "linux" "linux-firmware" "sudo" "systemd" "pacman"
    "bash" "coreutils" "util-linux" "glibc" "gcc" "binutils"
    "make" "fakeroot" "pkg-config" "which" "findutils" "grep"
    "gawk" "sed" "tar" "gzip"
)

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
    if [[ "$NO_DEPS" == true ]]; then
        echo -e "${YELLOW}⏭️  Skipping dependency scan${NC}"
        return
    fi
    
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
        
        # Get dependencies
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

cmd_get() {
    echo -e "${BLUE}📦 Getting all packages from your current system...${NC}"

    # Get ALL explicitly installed official packages (excluding AUR)
    echo -e "${BLUE}🔍 Scanning official packages...${NC}"
    pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}' > packages.txt

    # Get ALL AUR packages  
    echo -e "${BLUE}🔍 Scanning AUR packages...${NC}"
    pacman -Qm | awk '{print $1}' > aur-packages.txt

    echo -e "${GREEN}✅ Package lists updated!${NC}"
    echo
    echo -e "${BLUE}📊 Summary:${NC}"
    echo "  Official packages: $(wc -l < packages.txt)"
    echo "  AUR packages: $(wc -l < aur-packages.txt)"
    echo "  Total packages: $(($(wc -l < packages.txt) + $(wc -l < aur-packages.txt)))"

    echo
    echo -e "${GREEN}📁 Files updated:${NC}"
    echo "  - packages.txt"
    echo "  - aur-packages.txt"
}

cmd_get_quiet() {
    # Get ALL explicitly installed official packages (excluding AUR)
    pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}' > packages.txt

    # Get ALL AUR packages  
    pacman -Qm | awk '{print $1}' > aur-packages.txt

    echo -e "${GREEN}✅ Package lists synced${NC} (Official: $(wc -l < packages.txt), AUR: $(wc -l < aur-packages.txt))"
}

cmd_install() {
    echo -e "${BLUE}🚀 Smart Package Sync (Auto-Get + Full Sync)${NC}"
    echo
    
    # Step 1: Always get current packages first (auto-sync lists)
    echo -e "${BLUE}Step 1: Syncing package lists with current system...${NC}"
    cmd_get_quiet
    echo
    
    # Step 1.5: Filter packages based on hardware
    echo -e "${BLUE}Step 1.5: Filtering packages based on hardware...${NC}"
    
    # Show hardware detection only once
    local gpu_info=$(detect_gpu)
    local has_nvidia=$(echo "$gpu_info" | grep -o 'nvidia:[^,]*' | cut -d: -f2)
    if [[ "$has_nvidia" == "true" ]]; then
        echo -e "${GREEN}🖥️  NVIDIA GPU detected - keeping NVIDIA packages${NC}"
    else
        echo -e "${YELLOW}🖥️  No NVIDIA GPU detected - filtering NVIDIA packages${NC}"
    fi
    
    local filtered_packages=$(filter_packages_by_hardware packages.txt false)
    local filtered_aur_packages=$(filter_packages_by_hardware aur-packages.txt false)
    echo
    
    # Step 2: Quick analysis of changes needed
    echo -e "${BLUE}Step 2: Analyzing changes needed...${NC}"
    
    # Quick check of what would change
    local current_official=($(pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}'))
    local current_aur=($(pacman -Qm | awk '{print $1}'))
    local filtered_wanted_official=($(grep -v '^#\|^$' "$filtered_packages"))
    local filtered_wanted_aur=($(grep -v '^#\|^$' "$filtered_aur_packages"))
    
    # Count changes
    local missing_count=0
    local remove_count=0
    
    for pkg in "${filtered_wanted_official[@]}"; do
        if [[ ! " ${current_official[*]} " =~ " ${pkg} " ]]; then
            ((missing_count++))
        fi
    done
    
    for pkg in "${filtered_wanted_aur[@]}"; do
        if [[ ! " ${current_aur[*]} " =~ " ${pkg} " ]]; then
            ((missing_count++))
        fi
    done
    
    for pkg in "${current_official[@]}"; do
        if [[ ! " ${filtered_wanted_official[*]} " =~ " ${pkg} " ]] && [[ ! " ${essential_packages[*]} " =~ " ${pkg} " ]]; then
            ((remove_count++))
        fi
    done
    
    for pkg in "${current_aur[@]}"; do
        if [[ ! " ${filtered_wanted_aur[*]} " =~ " ${pkg} " ]]; then
            ((remove_count++))
        fi
    done
    
    if [[ $missing_count -eq 0 && $remove_count -eq 0 ]]; then
        echo -e "${GREEN}✅ System is already perfectly synced!${NC}"
        rm -f "$filtered_packages" "$filtered_aur_packages"
        return 0
    else
        echo -e "${YELLOW}📊 Changes needed:${NC} Install $missing_count, Remove $remove_count packages"
    fi
    
    # Step 3: Confirm if needed
    if [[ "$FORCE" != true ]]; then
        echo
        echo -e "${YELLOW}⚠️  This will install missing packages and remove unlisted ones${NC}"
        read -p "Continue with smart sync? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Smart sync cancelled.${NC}"
            return 0
        fi
    fi
    
    echo
    echo -e "${BLUE}Step 3: Executing smart sync...${NC}"
    
    # Find missing dependencies first
    find_missing_deps
    
    # Update system first
    echo -e "${BLUE}📦 Updating system...${NC}"
    
    # Check if we need to handle NVIDIA firmware conflicts during update
    if pacman -Q linux-firmware &>/dev/null && ! pacman -Q linux-firmware-nvidia &>/dev/null; then
        # Old linux-firmware installed but not new linux-firmware-nvidia
        # This means we might hit the firmware conflict during update
        echo -e "  ${YELLOW}⚠️  Detected NVIDIA firmware conflict, removing conflicting files...${NC}"
        
        # Remove the conflicting firmware directories that will be recreated
        sudo rm -rf /usr/lib/firmware/nvidia/ad10* 2>/dev/null || true
        sudo rm -rf /usr/lib/firmware/nvidia/ga10* 2>/dev/null || true
        sudo rm -rf /usr/lib/firmware/nvidia/tu10* 2>/dev/null || true
        sudo rm -rf /usr/lib/firmware/nvidia/gv100* 2>/dev/null || true
        
        echo -e "  ${GREEN}✅ Cleared conflicting NVIDIA firmware files${NC}"
    fi
    
    # Now try system update
    if ! sudo pacman -Syu --noconfirm; then
        echo -e "  ${RED}⚠️  System update failed, retrying with overwrite...${NC}"
        sudo pacman -Syu --noconfirm --overwrite="*"
    fi
    
    # Install missing official packages
    echo -e "${BLUE}📦 Installing missing official packages...${NC}"
    local missing_official=()
    while read -r package; do
        [[ "$package" =~ ^#.*$ ]] || [[ -z "$package" ]] && continue
        if ! pacman -Q "$package" &>/dev/null; then
            missing_official+=("$package")
        fi
    done < "$filtered_packages"

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
        cd "$DOTFILES_DIR"
    fi

    # Install missing AUR packages
    if [[ -s "$filtered_aur_packages" ]]; then
        echo -e "${BLUE}📦 Installing missing AUR packages...${NC}"
        local missing_aur=()
        while read -r package; do
            [[ "$package" =~ ^#.*$ ]] || [[ -z "$package" ]] && continue
            if ! pacman -Q "$package" &>/dev/null; then
                missing_aur+=("$package")
            fi
        done < "$filtered_aur_packages"
        
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
    
    # Step 4: Remove unwanted packages (full sync)
    echo -e "${BLUE}📦 Removing unlisted packages...${NC}"
    
    # Get current packages (fresh after installs)
    local current_official=($(pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}'))
    local current_aur=($(pacman -Qm | awk '{print $1}'))
    local wanted_official=($(grep -v '^#\|^$' "$filtered_packages"))
    local wanted_aur=($(grep -v '^#\|^$' "$filtered_aur_packages"))
    
    # Find packages to remove
    local to_remove_official=()
    for pkg in "${current_official[@]}"; do
        if [[ ! " ${wanted_official[*]} " =~ " ${pkg} " ]] && [[ ! " ${essential_packages[*]} " =~ " ${pkg} " ]]; then
            to_remove_official+=("$pkg")
        fi
    done
    
    local to_remove_aur=()
    for pkg in "${current_aur[@]}"; do
        if [[ ! " ${wanted_aur[*]} " =~ " ${pkg} " ]]; then
            to_remove_aur+=("$pkg")
        fi
    done
    
    # Remove packages
    if [[ ${#to_remove_official[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}Removing official:${NC} ${to_remove_official[*]}"
        if sudo pacman -Rns --noconfirm "${to_remove_official[@]}"; then
            echo -e "  ${GREEN}✅ Official packages removed${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Some packages couldn't be removed (dependencies)${NC}"
        fi
    fi
    
    if [[ ${#to_remove_aur[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}Removing AUR:${NC} ${to_remove_aur[*]}"
        if sudo pacman -Rns --noconfirm "${to_remove_aur[@]}"; then
            echo -e "  ${GREEN}✅ AUR packages removed${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Some packages couldn't be removed (dependencies)${NC}"
        fi
    fi
    
    if [[ ${#to_remove_official[@]} -eq 0 && ${#to_remove_aur[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}✅ No packages to remove${NC}"
    fi
    
    # Cleanup temporary files
    rm -f "$filtered_packages" "$filtered_aur_packages"
    
    echo
    echo -e "${GREEN}🎉 Smart sync complete!${NC}"
    echo -e "${BLUE}📊 Your system is now perfectly synced with your dotfiles${NC}"
}

cmd_check() {
    echo -e "${BLUE}📊 Package Status & Preview${NC}"
    echo
    
    if [[ ! -f "packages.txt" || ! -f "aur-packages.txt" ]]; then
        echo -e "${RED}❌ Package files not found! Run '$0 get' first${NC}"
        return 1
    fi
    
    # Show current status
    local current_official=($(pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}'))
    local current_aur=($(pacman -Qm | awk '{print $1}'))
    local wanted_official=($(grep -v '^#\|^$' packages.txt))
    local wanted_aur=($(grep -v '^#\|^$' aur-packages.txt))
    
    echo -e "${BLUE}📈 Current Status:${NC}"
    echo "  Official packages: ${#current_official[@]} installed, ${#wanted_official[@]} in list"
    echo "  AUR packages: ${#current_aur[@]} installed, ${#wanted_aur[@]} in list"
    echo
    
    # Hardware filtering preview
    echo -e "${BLUE}🔧 Hardware filtering...${NC}"
    
    # Show hardware detection only once
    local gpu_info=$(detect_gpu)
    local has_nvidia=$(echo "$gpu_info" | grep -o 'nvidia:[^,]*' | cut -d: -f2)
    if [[ "$has_nvidia" == "true" ]]; then
        echo -e "${GREEN}🖥️  NVIDIA GPU detected - keeping NVIDIA packages${NC}"
    else
        echo -e "${YELLOW}🖥️  No NVIDIA GPU detected - filtering NVIDIA packages${NC}"
    fi
    
    local filtered_packages=$(filter_packages_by_hardware packages.txt false)
    local filtered_aur_packages=$(filter_packages_by_hardware aur-packages.txt false)
    echo
    
    # Find differences
    local missing_official=()
    local missing_aur=()
    local to_remove_official=()
    local to_remove_aur=()
    
    # Get filtered package lists
    local filtered_wanted_official=($(grep -v '^#\|^$' "$filtered_packages"))
    local filtered_wanted_aur=($(grep -v '^#\|^$' "$filtered_aur_packages"))
    
    # Find missing packages
    for pkg in "${filtered_wanted_official[@]}"; do
        if [[ ! " ${current_official[*]} " =~ " ${pkg} " ]]; then
            missing_official+=("$pkg")
        fi
    done
    
    for pkg in "${filtered_wanted_aur[@]}"; do
        if [[ ! " ${current_aur[*]} " =~ " ${pkg} " ]]; then
            missing_aur+=("$pkg")
        fi
    done
    
    # Find packages to remove
    for pkg in "${current_official[@]}"; do
        if [[ ! " ${filtered_wanted_official[*]} " =~ " ${pkg} " ]] && [[ ! " ${essential_packages[*]} " =~ " ${pkg} " ]]; then
            to_remove_official+=("$pkg")
        fi
    done
    
    for pkg in "${current_aur[@]}"; do
        if [[ ! " ${filtered_wanted_aur[*]} " =~ " ${pkg} " ]]; then
            to_remove_aur+=("$pkg")
        fi
    done
    
    # Show preview
    echo -e "${BLUE}📋 Preview of Changes:${NC}"
    
    local total_install=$((${#missing_official[@]} + ${#missing_aur[@]}))
    local total_remove=$((${#to_remove_official[@]} + ${#to_remove_aur[@]}))
    
    if [[ $total_install -eq 0 && $total_remove -eq 0 ]]; then
        echo -e "${GREEN}✅ System is perfectly synced! No changes needed.${NC}"
    else
        echo -e "${YELLOW}📊 Changes needed:${NC} Install $total_install, Remove $total_remove packages"
        echo
        
        if [[ ${#missing_official[@]} -gt 0 || ${#missing_aur[@]} -gt 0 ]]; then
            echo -e "${GREEN}📦 TO INSTALL:${NC}"
            [[ ${#missing_official[@]} -gt 0 ]] && echo -e "  Official (${#missing_official[@]}): ${missing_official[*]}"
            [[ ${#missing_aur[@]} -gt 0 ]] && echo -e "  AUR (${#missing_aur[@]}): ${missing_aur[*]}"
            echo
        fi
        
        if [[ ${#to_remove_official[@]} -gt 0 || ${#to_remove_aur[@]} -gt 0 ]]; then
            echo -e "${RED}🗑️  TO REMOVE:${NC}"
            [[ ${#to_remove_official[@]} -gt 0 ]] && echo -e "  Official (${#to_remove_official[@]}): ${to_remove_official[*]}"
            [[ ${#to_remove_aur[@]} -gt 0 ]] && echo -e "  AUR (${#to_remove_aur[@]}): ${to_remove_aur[*]}"
        fi
    fi
    
    # Cleanup temporary files
    rm -f "$filtered_packages" "$filtered_aur_packages"
}

# Execute command
case "$COMMAND" in
    get)
        cmd_get
        ;;
    install)
        cmd_install
        ;;
    check)
        cmd_check
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $COMMAND${NC}"
        exit 1
        ;;
esac 