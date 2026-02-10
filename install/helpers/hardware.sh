#!/bin/bash
# Hardware detection helpers

# Detect GPU types
detect_gpu() {
    local has_nvidia=false
    local has_amd=false
    local has_intel=false
    
    # Check for NVIDIA
    if lspci | grep -i nvidia &>/dev/null || lsmod | grep -i nvidia &>/dev/null; then
        has_nvidia=true
    fi
    
    # Check for AMD
    if lspci | grep -iE "vga.*amd|vga.*ati|display.*amd|display.*ati" &>/dev/null; then
        has_amd=true
    fi
    
    # Check for Intel
    if lspci | grep -iE "vga.*intel|display.*intel" &>/dev/null; then
        has_intel=true
    fi
    
    echo "nvidia:$has_nvidia,amd:$has_amd,intel:$has_intel"
}

# Check if NVIDIA GPU is present
has_nvidia_gpu() {
    local gpu_info=$(detect_gpu)
    [[ "$gpu_info" == *"nvidia:true"* ]]
}

# Check if AMD GPU is present
has_amd_gpu() {
    local gpu_info=$(detect_gpu)
    [[ "$gpu_info" == *"amd:true"* ]]
}

# Check if Intel GPU is present
has_intel_gpu() {
    local gpu_info=$(detect_gpu)
    [[ "$gpu_info" == *"intel:true"* ]]
}

# Detect device type (laptop vs desktop)
detect_device_type() {
    # Check for laptop built-in display names
    if command -v hyprctl &>/dev/null && hyprctl monitors &>/dev/null 2>&1; then
        if hyprctl monitors 2>/dev/null | grep -qE "Monitor (eDP|LVDS|DSI)"; then
            echo "laptop"
            return
        fi
    fi
    
    # Fallback: check for battery
    if [[ -d /sys/class/power_supply/BAT* ]] 2>/dev/null; then
        echo "laptop"
        return
    fi
    
    # Check chassis type via dmidecode (if available)
    if command -v dmidecode &>/dev/null && sudo -n dmidecode -s chassis-type 2>/dev/null | grep -qiE "notebook|laptop|portable"; then
        echo "laptop"
        return
    fi
    
    echo "desktop"
}

# Check if device is a laptop
is_laptop() {
    [[ "$(detect_device_type)" == "laptop" ]]
}

# Check if device is a desktop
is_desktop() {
    [[ "$(detect_device_type)" == "desktop" ]]
}

# Filter packages based on hardware
filter_packages_by_hardware() {
    local package_file="$1"
    local temp_file
    
    # Create temporary file (caller is responsible for cleanup)
    temp_file=$(mktemp)
    
    # Validate input file
    if [[ ! -f "$package_file" || ! -r "$package_file" ]]; then
        log_error "Package file not found or not readable: $package_file" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    # NVIDIA-specific packages to filter
    local nvidia_packages=(
        "nvidia"
        "nvidia-open-dkms"
        "nvidia-prime"
        "nvidia-settings"
        "nvidia-utils"
        "python-nvidia-ml-py"
    )
    
    if has_nvidia_gpu; then
        # Keep all packages if NVIDIA is present
        cp "$package_file" "$temp_file"
        log_info "NVIDIA GPU detected - keeping NVIDIA packages" >&2
    else
        # Filter out NVIDIA packages if no NVIDIA hardware
        log_info "No NVIDIA GPU detected - filtering NVIDIA packages" >&2
        
        while IFS= read -r line; do
            # Keep comments and empty lines as-is
            if [[ "$line" =~ ^#.*$ || -z "$line" ]]; then
                echo "$line" >> "$temp_file"
                continue
            fi
            
            # Check if this is a NVIDIA package to filter
            local should_keep=true
            for nvidia_pkg in "${nvidia_packages[@]}"; do
                if [[ "$line" == "$nvidia_pkg" ]]; then
                    should_keep=false
                    log_info "  Skipping: $nvidia_pkg (no NVIDIA hardware)" >&2
                    break
                fi
            done
            
            if $should_keep; then
                echo "$line" >> "$temp_file"
            fi
        done < "$package_file"
    fi
    
    # Output the filtered file path
    echo "$temp_file"
}

# Show hardware summary
show_hardware_info() {
    log_section "Hardware Information"
    
    # Device type
    local device_type=$(detect_device_type)
    show_info "Device Type" "$device_type"
    
    # GPU info
    local gpu_info=$(detect_gpu)
    local gpu_list=()
    
    if has_nvidia_gpu; then
        gpu_list+=("NVIDIA")
    fi
    if has_amd_gpu; then
        gpu_list+=("AMD")
    fi
    if has_intel_gpu; then
        gpu_list+=("Intel")
    fi
    
    if [[ ${#gpu_list[@]} -gt 0 ]]; then
        show_info "GPU(s)" "${gpu_list[*]}"
    else
        show_info "GPU(s)" "Unknown"
    fi
    
    # CPU info
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
        show_info "CPU" "$cpu_model"
    fi
    
    # Memory
    if command -v free &>/dev/null; then
        local mem_total=$(free -h | awk '/^Mem:/ {print $2}')
        show_info "Memory" "$mem_total"
    fi
    
    echo
}

