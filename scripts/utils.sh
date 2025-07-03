#!/bin/bash

# utils.sh - Shared utilities for dotfiles scripts
# Common functions to reduce code duplication

# Colors
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export PURPLE='\033[0;35m'
export NC='\033[0m'

# Common paths
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
export STOW_DIR="$DOTFILES_DIR/stow"


# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${BLUE}🚀 $1${NC}"
}

log_section() {
    echo
    echo -e "${PURPLE}═══ $1 ═══${NC}"
    echo
}

# Check if command exists
has_command() {
    command -v "$1" &> /dev/null
}

# Check if running on specific OS
is_arch() {
    [[ -f /etc/arch-release ]]
}

# Check if directory exists and is not empty
dir_exists_and_not_empty() {
    [[ -d "$1" && -n "$(ls -A "$1" 2>/dev/null)" ]]
}

# Simple backup with timestamp (if needed)
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup_file="$file.bak"
        cp "$file" "$backup_file"
        [[ "$QUIET" != true ]] && log_info "📦 Backed up $(basename "$file") to $(basename "$backup_file")"
        echo "$backup_file"
    fi
}

# Check if script is run with sudo when needed
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        return 1
    fi
    return 0
}

# Confirm action with user
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    
    local prompt="$message (y/N): "
    if [[ "$default" == "y" ]]; then
        prompt="$message (Y/n): "
    fi
    
    read -p "$prompt" -n 1 -r
    echo
    
    if [[ "$default" == "y" ]]; then
        [[ $REPLY =~ ^[Nn]$ ]] && return 1
    else
        [[ $REPLY =~ ^[Yy]$ ]] || return 1
    fi
    
    return 0
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

# Download file with retry
download_file() {
    local url="$1"
    local output="$2"
    local retries="${3:-3}"
    
    for ((i=1; i<=retries; i++)); do
        if curl -fsSL "$url" -o "$output"; then
            return 0
        fi
        
        if [[ $i -lt $retries ]]; then
            log_warning "Download failed, retrying ($i/$retries)..."
            sleep 2
        fi
    done
    
    log_error "Failed to download $url after $retries attempts"
    return 1
}

# Clone git repo with error handling
clone_repo() {
    local url="$1"
    local dir="$2"
    local depth="${3:-1}"
    
    if git clone "$url" "$dir" --depth="$depth"; then
        return 0
    else
        log_error "Failed to clone $url"
        return 1
    fi
}

# Check if package is installed (Arch-specific)
is_package_installed() {
    local package="$1"
    pacman -Q "$package" &>/dev/null
}

# Get package manager command
get_install_cmd() {
    if has_command yay; then
        echo "yay -S --needed --noconfirm"
    elif has_command paru; then
        echo "paru -S --needed --noconfirm"
    else
        echo "sudo pacman -S --needed --noconfirm"
    fi
}

# Get AUR helper install command
get_aur_cmd() {
    if has_command yay; then
        echo "yay -S --needed --noconfirm"
    elif has_command paru; then
        echo "paru -S --needed --noconfirm"
    else
        log_error "No AUR helper found. Install yay or paru first."
        return 1
    fi
}

# Progress indicator
show_progress() {
    local current="$1"
    local total="$2"
    local task="$3"
    
    local percentage=$((current * 100 / total))
    local bar_length=30
    local filled_length=$((current * bar_length / total))
    
    printf "\r${BLUE}[${"
    for ((i=0; i<filled_length; i++)); do printf "█"; done
    for ((i=filled_length; i<bar_length; i++)); do printf "░"; done
    printf "}] %d%% (%d/%d) %s${NC}" "$percentage" "$current" "$total" "$task"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Timer functions
start_timer() {
    export TIMER_START=$(date +%s)
}

stop_timer() {
    local end_time=$(date +%s)
    local duration=$((end_time - TIMER_START))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    if [[ $minutes -gt 0 ]]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# System information
get_system_info() {
    echo "OS: $(uname -s) $(uname -r)"
    echo "Architecture: $(uname -m)"
    if [[ -f /etc/os-release ]]; then
        echo "Distribution: $(source /etc/os-release; echo "$PRETTY_NAME")"
    fi
    echo "User: $USER"
    echo "Home: $HOME"
    echo "Shell: $SHELL"
}

# Check prerequisites
check_prerequisites() {
    local missing=()
    
    # Essential commands
    local required_commands=("git" "curl" "stow")
    
    for cmd in "${required_commands[@]}"; do
        if ! has_command "$cmd"; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        log_info "Install them first: sudo pacman -S ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Cleanup temporary files
cleanup_temp() {
    local temp_pattern="$1"
    # Implementation would go here
}



# Export functions for use in other scripts
export -f log_info log_success log_warning log_error log_step log_section
export -f has_command is_arch dir_exists_and_not_empty backup_file
export -f check_sudo confirm_action ensure_dir download_file clone_repo
export -f is_package_installed get_install_cmd get_aur_cmd
export -f show_progress start_timer stop_timer get_system_info
export -f check_prerequisites cleanup_temp 