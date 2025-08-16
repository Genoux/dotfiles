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
    local temp_file
    local show_status="$2"  # Optional parameter to show status
    
    # Securely create temporary file with proper permissions
    temp_file=$(mktemp --tmpdir="$HOME" "pkg-filter-$$-XXXXXXXX")
    
    # Trap to ensure cleanup on exit/error
    trap 'rm -f "$temp_file" 2>/dev/null' EXIT INT TERM
    
    # Validate input file exists and is readable
    if [[ ! -f "$package_file" || ! -r "$package_file" ]]; then
        echo "Error: Package file not found or not readable: $package_file" >&2
        return 1
    fi
    
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
    
    # Clear trap since we're returning the temp file path for caller to handle
    trap - EXIT INT TERM
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

    # Get ALL AUR packages first to use for filtering
    echo -e "${BLUE}🔍 Scanning AUR packages...${NC}"
    local aur_packages_temp=$(mktemp)
    pacman -Qm | awk '{print $1}' > "$aur_packages_temp"
    
    # Create escaped regex pattern for grep
    local aur_pattern=""
    if [[ -s "$aur_packages_temp" ]]; then
        # Escape special regex characters in package names
        aur_pattern=$(sed 's/[[\.*^$()+?{|]/\\&/g' "$aur_packages_temp" | paste -sd'|')
    fi

    # Get ALL explicitly installed official packages (excluding AUR)
    echo -e "${BLUE}🔍 Scanning official packages...${NC}"
    if [[ -n "$aur_pattern" ]]; then
        pacman -Qe | grep -v -E "^($aur_pattern) " | awk '{print $1}' > packages.txt
    else
        pacman -Qe | awk '{print $1}' > packages.txt
    fi

    # Copy AUR packages to final file
    cp "$aur_packages_temp" aur-packages.txt
    
    # Cleanup
    rm -f "$aur_packages_temp"

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
    # Get ALL AUR packages first to use for filtering
    local aur_packages_temp=$(mktemp)
    pacman -Qm | awk '{print $1}' > "$aur_packages_temp"
    
    # Create escaped regex pattern for grep
    local aur_pattern=""
    if [[ -s "$aur_packages_temp" ]]; then
        # Escape special regex characters in package names
        aur_pattern=$(sed 's/[[\.*^$()+?{|]/\\&/g' "$aur_packages_temp" | paste -sd'|')
    fi
    
    # Get ALL explicitly installed official packages (excluding AUR)
    if [[ -n "$aur_pattern" ]]; then
        pacman -Qe | grep -v -E "^($aur_pattern) " | awk '{print $1}' > packages.txt
    else
        pacman -Qe | awk '{print $1}' > packages.txt
    fi

    # Copy AUR packages to final file
    cp "$aur_packages_temp" aur-packages.txt
    
    # Cleanup
    rm -f "$aur_packages_temp"

    echo -e "${GREEN}✅ Package lists synced${NC} (Official: $(wc -l < packages.txt), AUR: $(wc -l < aur-packages.txt))"
}

cmd_install() {
    echo -e "${BLUE}🚀 Smart Package Sync (System → Dotfiles + Dependencies)${NC}"
    echo
    
    # Step 1: Always sync package lists with current system first
    echo -e "${BLUE}Step 1: Syncing package lists with current system...${NC}"
    cmd_get_quiet
    echo
    
    # Step 2: Find and install missing dependencies
    echo -e "${BLUE}Step 2: Finding missing dependencies...${NC}"
    find_missing_deps
    
    # Step 3: System update
    echo -e "${BLUE}Step 3: Updating system...${NC}"
    echo -e "${YELLOW}Note: You may need to answer prompts for package conflicts/replacements${NC}"
    
    # Interactive system update to handle conflicts
    if sudo pacman -Syu; then
        echo -e "  ${GREEN}✅ System updated successfully${NC}"
    else
        echo -e "  ${RED}⚠️  System update failed${NC}"
        echo -e "  ${YELLOW}You may need to resolve conflicts manually${NC}"
    fi
    
    echo
    echo -e "${GREEN}🎉 Smart sync complete!${NC}"
    echo -e "${BLUE}📊 Your dotfiles now reflect your current system${NC}"
    echo -e "${BLUE}📊 Missing dependencies have been found and added${NC}"
}

cmd_check() {
    echo -e "${BLUE}📊 Package Status & Sync Preview${NC}"
    echo
    
    if [[ ! -f "packages.txt" || ! -f "aur-packages.txt" ]]; then
        echo -e "${YELLOW}⚠️  Package files not found! They will be created on first sync.${NC}"
        echo -e "${BLUE}📈 Current System:${NC}"
        local aur_count=$(pacman -Qm | wc -l)
        local official_count=$(pacman -Qe | wc -l)
        echo "  Official packages: $((official_count - aur_count)) installed"
        echo "  AUR packages: $aur_count installed"
        echo "  Total: $official_count packages"
        echo
        echo -e "${GREEN}✅ Smart Sync will create package lists from your current system${NC}"
        return 0
    fi
    
    # Show current status vs dotfiles
    local aur_pattern=$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')
    local current_official=()
    if [[ -n "$aur_pattern" ]]; then
        current_official=($(pacman -Qe | grep -v -E "^($aur_pattern) " | awk '{print $1}'))
    else
        current_official=($(pacman -Qe | awk '{print $1}'))
    fi
    local current_aur=($(pacman -Qm | awk '{print $1}'))
    local dotfiles_official=($(grep -v '^#\|^$' packages.txt))
    local dotfiles_aur=($(grep -v '^#\|^$' aur-packages.txt))
    
    echo -e "${BLUE}📈 Current Status:${NC}"
    echo "  System:   Official ${#current_official[@]}, AUR ${#current_aur[@]} (total: $((${#current_official[@]} + ${#current_aur[@]})))"
    echo "  Dotfiles: Official ${#dotfiles_official[@]}, AUR ${#dotfiles_aur[@]} (total: $((${#dotfiles_official[@]} + ${#dotfiles_aur[@]})))"
    echo
    
    # Find differences between system and dotfiles
    local added_to_system=()
    local removed_from_system=()
    
    # Packages added to system (not in dotfiles)
    for pkg in "${current_official[@]}"; do
        if [[ ! " ${dotfiles_official[*]} " =~ " ${pkg} " ]]; then
            added_to_system+=("$pkg")
        fi
    done
    
    for pkg in "${current_aur[@]}"; do
        if [[ ! " ${dotfiles_aur[*]} " =~ " ${pkg} " ]]; then
            added_to_system+=("$pkg")
        fi
    done
    
    # Packages removed from system (in dotfiles but not installed)
    for pkg in "${dotfiles_official[@]}"; do
        if [[ ! " ${current_official[*]} " =~ " ${pkg} " ]]; then
            removed_from_system+=("$pkg")
        fi
    done
    
    for pkg in "${dotfiles_aur[@]}"; do
        if [[ ! " ${current_aur[*]} " =~ " ${pkg} " ]]; then
            removed_from_system+=("$pkg")
        fi
    done
    
    # Show what Smart Sync will do
    echo -e "${BLUE}📋 Smart Sync Preview (System → Dotfiles):${NC}"
    
    if [[ ${#added_to_system[@]} -eq 0 && ${#removed_from_system[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ System and dotfiles are already in sync!${NC}"
    else
        if [[ ${#added_to_system[@]} -gt 0 ]]; then
            echo -e "${GREEN}📝 Will ADD to dotfiles:${NC} ${added_to_system[*]}"
        fi
        
        if [[ ${#removed_from_system[@]} -gt 0 ]]; then
            echo -e "${YELLOW}📝 Will REMOVE from dotfiles:${NC} ${removed_from_system[*]}"
        fi
        
        echo
        echo -e "${BLUE}💡 After sync, dotfiles will match your current system exactly${NC}"
    fi
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