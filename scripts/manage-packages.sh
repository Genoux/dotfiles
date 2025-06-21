#!/bin/bash

# manage-packages.sh - Unified package management for dotfiles
# Handles getting, installing, syncing packages across systems

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
    echo -e "${BLUE}📦 Package Manager for Dotfiles${NC}"
    echo
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo -e "  ${GREEN}install${NC}   Auto-sync packages (default - does everything)"
    echo -e "  ${GREEN}themes${NC}    Install custom themes only"
    echo -e "  ${GREEN}status${NC}    Show current package status"
    echo -e "  ${GREEN}preview${NC}   Preview what would change"
    echo
    echo "Advanced (rarely needed):"
    echo -e "  ${GREEN}get${NC}       Just update package lists from system"
    echo -e "  ${GREEN}setup${NC}     Complete setup (install + themes)"
    echo
    echo "Options:"
    echo "  --force     Skip confirmations"
    echo "  --no-deps   Skip dependency scanning"
    echo
    echo "Examples:"
    echo -e "  ${GREEN}$0${NC}                        # Smart install (recommended)"
    echo -e "  ${GREEN}$0 install${NC}               # Same as above"
    echo -e "  ${GREEN}$0 install --force${NC}       # No confirmations"
    echo -e "  ${GREEN}$0 themes${NC}                # Just install themes"
    echo -e "  ${GREEN}$0 status${NC}                # Check what would happen"
    echo
    echo -e "${YELLOW}💡 Pro tip: Just run '${GREEN}$0${NC}${YELLOW}' and it handles everything!${NC}"
}

# Parse arguments
COMMAND=""
FORCE=false
NO_DEPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        get|install|sync|preview|setup|themes|status)
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

# Default to smart install if no command given
if [[ -z "$COMMAND" ]]; then
    COMMAND="install"
fi

# Change to dotfiles directory
cd "$DOTFILES_DIR"

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

cmd_status() {
    echo -e "${BLUE}📊 Package Status${NC}"
    echo
    
    if [[ ! -f "packages.txt" || ! -f "aur-packages.txt" ]]; then
        echo -e "${RED}❌ Package files not found! Run '$0 get' first${NC}"
        return 1
    fi
    
    # Get current packages
    local current_official=($(pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}'))
    local current_aur=($(pacman -Qm | awk '{print $1}'))
    
    # Get wanted packages
    local wanted_official=($(grep -v '^#\|^$' packages.txt))
    local wanted_aur=($(grep -v '^#\|^$' aur-packages.txt))
    
    echo "Current vs Wanted:"
    echo "  Current official: ${#current_official[@]}"
    echo "  Wanted official: ${#wanted_official[@]}"
    echo "  Current AUR: ${#current_aur[@]}"
    echo "  Wanted AUR: ${#wanted_aur[@]}"
    
    # Quick check
    local missing_count=0
    local extra_count=0
    
    for pkg in "${wanted_official[@]}"; do
        if [[ ! " ${current_official[*]} " =~ " ${pkg} " ]]; then
            ((missing_count++))
        fi
    done
    
    for pkg in "${wanted_aur[@]}"; do
        if [[ ! " ${current_aur[*]} " =~ " ${pkg} " ]]; then
            ((missing_count++))
        fi
    done
    
    for pkg in "${current_official[@]}"; do
        if [[ ! " ${wanted_official[*]} " =~ " ${pkg} " ]] && [[ ! " ${essential_packages[*]} " =~ " ${pkg} " ]]; then
            ((extra_count++))
        fi
    done
    
    for pkg in "${current_aur[@]}"; do
        if [[ ! " ${wanted_aur[*]} " =~ " ${pkg} " ]]; then
            ((extra_count++))
        fi
    done
    
    echo
    if [[ $missing_count -eq 0 && $extra_count -eq 0 ]]; then
        echo -e "${GREEN}✅ System is in perfect sync!${NC}"
    else
        echo -e "${YELLOW}⚠️  System is out of sync:${NC}"
        [[ $missing_count -gt 0 ]] && echo "  Missing packages: $missing_count"
        [[ $extra_count -gt 0 ]] && echo "  Extra packages: $extra_count"
        echo
        echo -e "${BLUE}💡 Run '$0 preview' for details${NC}"
    fi
}

cmd_preview() {
    echo -e "${BLUE}🔍 Previewing sync changes...${NC}"

    if [[ ! -f "packages.txt" || ! -f "aur-packages.txt" ]]; then
        echo -e "${RED}❌ Package files not found! Run '$0 get' first${NC}"
        return 1
    fi

    # Get current and wanted packages
    local current_official=($(pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}'))
    local current_aur=($(pacman -Qm | awk '{print $1}'))
    local wanted_official=($(grep -v '^#\|^$' packages.txt))
    local wanted_aur=($(grep -v '^#\|^$' aur-packages.txt))

    # Find packages to install
    local missing_official=()
    for pkg in "${wanted_official[@]}"; do
        if [[ ! " ${current_official[*]} " =~ " ${pkg} " ]]; then
            missing_official+=("$pkg")
        fi
    done

    local missing_aur=()
    for pkg in "${wanted_aur[@]}"; do
        if [[ ! " ${current_aur[*]} " =~ " ${pkg} " ]]; then
            missing_aur+=("$pkg")
        fi
    done

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

    # Display results
    echo
    echo -e "${GREEN}📦 PACKAGES TO INSTALL:${NC}"
    if [[ ${#missing_official[@]} -gt 0 ]]; then
        echo "Official (${#missing_official[@]}):"
        printf '  %s\n' "${missing_official[@]}"
    fi
    if [[ ${#missing_aur[@]} -gt 0 ]]; then
        echo "AUR (${#missing_aur[@]}):"
        printf '  %s\n' "${missing_aur[@]}"
    fi
    if [[ ${#missing_official[@]} -eq 0 && ${#missing_aur[@]} -eq 0 ]]; then
        echo "  None"
    fi

    echo
    echo -e "${RED}🗑️  PACKAGES TO REMOVE:${NC}"
    if [[ ${#to_remove_official[@]} -gt 0 ]]; then
        echo "Official (${#to_remove_official[@]}):"
        printf '  %s\n' "${to_remove_official[@]}"
    fi
    if [[ ${#to_remove_aur[@]} -gt 0 ]]; then
        echo "AUR (${#to_remove_aur[@]}):"
        printf '  %s\n' "${to_remove_aur[@]}"
    fi
    if [[ ${#to_remove_official[@]} -eq 0 && ${#to_remove_aur[@]} -eq 0 ]]; then
        echo "  None"
    fi

    if [[ ${#missing_official[@]} -eq 0 && ${#missing_aur[@]} -eq 0 && ${#to_remove_official[@]} -eq 0 && ${#to_remove_aur[@]} -eq 0 ]]; then
        echo
        echo -e "${GREEN}✅ System is already in perfect sync!${NC}"
    fi
}

cmd_preview_quiet() {
    # Get current and wanted packages
    local current_official=($(pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}'))
    local current_aur=($(pacman -Qm | awk '{print $1}'))
    local wanted_official=($(grep -v '^#\|^$' packages.txt))
    local wanted_aur=($(grep -v '^#\|^$' aur-packages.txt))

    # Find packages to install
    local missing_official=()
    for pkg in "${wanted_official[@]}"; do
        if [[ ! " ${current_official[*]} " =~ " ${pkg} " ]]; then
            missing_official+=("$pkg")
        fi
    done

    local missing_aur=()
    for pkg in "${wanted_aur[@]}"; do
        if [[ ! " ${current_aur[*]} " =~ " ${pkg} " ]]; then
            missing_aur+=("$pkg")
        fi
    done

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

    # Display compact results
    local install_count=$((${#missing_official[@]} + ${#missing_aur[@]}))
    local remove_count=$((${#to_remove_official[@]} + ${#to_remove_aur[@]}))
    
    if [[ $install_count -eq 0 && $remove_count -eq 0 ]]; then
        echo -e "${GREEN}✅ System is already in perfect sync!${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}📊 Changes needed:${NC} Install $install_count, Remove $remove_count packages"
    
    [[ ${#missing_official[@]} -gt 0 ]] && echo -e "  ${GREEN}+${NC} Official: ${missing_official[*]}"
    [[ ${#missing_aur[@]} -gt 0 ]] && echo -e "  ${GREEN}+${NC} AUR: ${missing_aur[*]}"
    [[ ${#to_remove_official[@]} -gt 0 ]] && echo -e "  ${RED}-${NC} Official: ${to_remove_official[*]}"
    [[ ${#to_remove_aur[@]} -gt 0 ]] && echo -e "  ${RED}-${NC} AUR: ${to_remove_aur[*]}"
}

cmd_install() {
    echo -e "${BLUE}🚀 Smart Package Sync (Auto-Get + Full Sync)${NC}"
    echo
    
    # Step 1: Always get current packages first (auto-sync lists)
    echo -e "${BLUE}Step 1: Syncing package lists with current system...${NC}"
    cmd_get_quiet
    echo
    
    # Step 2: Preview what will change
    echo -e "${BLUE}Step 2: Analyzing changes needed...${NC}"
    cmd_preview_quiet
    
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
    sudo pacman -Syu --noconfirm
    
    # Install missing official packages
    echo -e "${BLUE}📦 Installing missing official packages...${NC}"
    local missing_official=()
    while read -r package; do
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
        cd "$DOTFILES_DIR"
    fi

    # Install missing AUR packages
    if [[ -s "aur-packages.txt" ]]; then
        echo -e "${BLUE}📦 Installing missing AUR packages...${NC}"
        local missing_aur=()
        while read -r package; do
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
    
    # Step 4: Remove unwanted packages (full sync)
    echo -e "${BLUE}📦 Removing unlisted packages...${NC}"
    
    # Get current packages (fresh after installs)
    local current_official=($(pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}'))
    local current_aur=($(pacman -Qm | awk '{print $1}'))
    local wanted_official=($(grep -v '^#\|^$' packages.txt))
    local wanted_aur=($(grep -v '^#\|^$' aur-packages.txt))
    
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
    
    echo
    echo -e "${GREEN}🎉 Smart sync complete!${NC}"
    echo -e "${BLUE}📊 Your system is now perfectly synced with your dotfiles${NC}"
}

cmd_sync() {
    echo -e "${BLUE}🔄 Syncing packages (install missing + remove unlisted)...${NC}"
    
    if [[ ! -f "packages.txt" || ! -f "aur-packages.txt" ]]; then
        echo -e "${RED}❌ Package files not found! Run '$0 get' first${NC}"
        return 1
    fi
    
    # Show what will happen
    cmd_preview
    
    if [[ "$FORCE" != true ]]; then
        echo
        echo -e "${YELLOW}⚠️  This will PERMANENTLY REMOVE unlisted packages!${NC}"
        read -p "Continue with sync? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Sync cancelled.${NC}"
            return 0
        fi
    fi
    
    # First install missing packages
    cmd_install
    
    # Then remove unwanted packages
    echo -e "${BLUE}🗑️  Removing unlisted packages...${NC}"
    
    # Get current packages
    local current_official=($(pacman -Qe | grep -v "$(pacman -Qm | cut -d' ' -f1 | paste -sd'|')" | awk '{print $1}'))
    local current_aur=($(pacman -Qm | awk '{print $1}'))
    local wanted_official=($(grep -v '^#\|^$' packages.txt))
    local wanted_aur=($(grep -v '^#\|^$' aur-packages.txt))
    
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
    
    echo -e "${GREEN}✅ Sync complete!${NC}"
}

cmd_themes() {
    echo -e "${BLUE}🎨 Installing custom themes...${NC}"
    
    if [[ -f "$SCRIPT_DIR/install-themes.sh" ]]; then
        local force_flag=""
        if [[ "$FORCE" == true ]]; then
            force_flag="--force"
        fi
        bash "$SCRIPT_DIR/install-themes.sh" $force_flag
    else
        echo -e "${RED}❌ install-themes.sh not found!${NC}"
        return 1
    fi
}

cmd_setup() {
    echo -e "${BLUE}🚀 Complete system setup...${NC}"
    echo
    
    # Step 1: Smart sync packages (auto-get + sync)
    echo -e "${BLUE}Step 1: Smart syncing packages...${NC}"
    cmd_install
    echo
    
    # Step 2: Install themes
    echo -e "${BLUE}Step 2: Installing themes...${NC}"
    cmd_themes
    echo
    
    echo -e "${GREEN}🎉 Complete setup finished!${NC}"
    echo
    echo -e "${YELLOW}💡 Next steps:${NC}"
    echo "  • Install configs: Use dotfiles menu option 7"
    echo "  • Restart desktop environment"
    echo "  • Log out and back in for full effect"
}

# Execute command
case "$COMMAND" in
    get)
        cmd_get
        ;;
    install)
        cmd_install
        ;;
    sync)
        # Legacy support - redirect to install
        echo -e "${YELLOW}💡 'sync' command is now 'install' (does the same thing)${NC}"
        cmd_install
        ;;
    preview)
        cmd_preview
        ;;
    setup)
        cmd_setup
        ;;
    themes)
        cmd_themes
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