#!/bin/bash
# CPU Frequency Scaling Setup
# Enables proper CPU frequency scaling for AMD Ryzen 4000 series

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SYSTEM_DIR="$DOTFILES_DIR/system"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
else
    # Ensure helpers are sourced even if flag is set (might be from different shell)
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "CPU Frequency Scaling"

# Remove any existing blacklist for acpi-cpufreq (conflicts with our setup)
if [[ -f /etc/modprobe.d/blacklist-acpi-cpufreq.conf ]]; then
    sudo rm /etc/modprobe.d/blacklist-acpi-cpufreq.conf
    log_success "Removed acpi-cpufreq blacklist"
fi

# Copy module load configuration
if [[ -f "$SYSTEM_DIR/modules-load.d/cpufreq.conf" ]]; then
    sudo mkdir -p /etc/modules-load.d
    sudo cp "$SYSTEM_DIR/modules-load.d/cpufreq.conf" /etc/modules-load.d/cpufreq.conf
    log_success "cpufreq.conf"
fi

# Load the module now (without reboot)
if sudo modprobe acpi-cpufreq 2>/dev/null; then
    log_success "acpi-cpufreq module loaded"
else
    log_warning "Module will be loaded after reboot"
fi

# Check if cpupower is installed
if ! command -v cpupower &>/dev/null; then
    log_info "Installing cpupower..."
    sudo pacman -S --needed --noconfirm cpupower
fi

# Set CPU governor to schedutil (best for laptops)
if sudo cpupower frequency-set -g schedutil 2>/dev/null; then
    log_success "CPU governor set to schedutil"
else
    log_warning "CPU governor will be set after reboot"
fi

# Enable cpupower service
sudo systemctl enable cpupower.service 2>/dev/null || true
log_success "cpupower.service enabled"

# Set reboot needed flag
mkdir -p "$HOME/.local/state/dotfiles"
touch "$HOME/.local/state/dotfiles/.reboot_needed"
