#!/bin/bash
# Hyprland configuration operations

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
MONITORS_CONF="$HOME/.config/hypr/monitors.conf"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Check if Hyprland is installed
check_hyprland() {
    if ! command -v hyprctl &>/dev/null; then
        graceful_error "Hyprland not installed" "Install with: sudo pacman -S hyprland"
        return 1
    fi
    return 0
}

# Get maximum refresh rate for a monitor resolution
get_max_refresh_rate() {
    local monitor_name="$1"
    local target_resolution="$2"
    local max_refresh=60.0
    
    if ! command -v hyprctl &>/dev/null || ! hyprctl monitors &>/dev/null 2>&1; then
        echo "$max_refresh"
        return
    fi
    
    local hypr_output=$(hyprctl monitors 2>/dev/null)
    local in_monitor_section=false
    
    while IFS= read -r line; do
        if [[ $line =~ ^Monitor\ $monitor_name\ \(ID ]]; then
            in_monitor_section=true
        elif [[ $line =~ ^Monitor\ [^[:space:]]+\ \(ID ]] && [[ $in_monitor_section == true ]]; then
            in_monitor_section=false
        elif [[ $in_monitor_section == true && $line =~ ^[[:space:]]*availableModes: ]]; then
            local modes_line="${line#*availableModes: }"
            
            while [[ $modes_line =~ $target_resolution@([0-9]+\.[0-9]+)Hz ]]; do
                local refresh_rate="${BASH_REMATCH[1]}"
                local refresh_int=$(echo "$refresh_rate" | sed 's/\.//' | sed 's/^0*//' | sed 's/^$/0/')
                local max_int=$(echo "$max_refresh" | sed 's/\.//' | sed 's/^0*//' | sed 's/^$/0/')
                
                if [[ $refresh_int -gt $max_int ]]; then
                    max_refresh="$refresh_rate"
                fi
                
                modes_line="${modes_line#*${BASH_REMATCH[0]}}"
            done
            break
        fi
    done <<< "$hypr_output"
    
    echo "$max_refresh"
}

# Get best mode for a monitor
get_monitor_best_mode() {
    local monitor_name="$1"
    local best_resolution="1920x1080"
    local max_pixels=0
    
    if ! command -v hyprctl &>/dev/null || ! hyprctl monitors &>/dev/null 2>&1; then
        echo "$best_resolution@60.0"
        return
    fi
    
    local hypr_output=$(hyprctl monitors 2>/dev/null)
    local in_monitor_section=false
    
    while IFS= read -r line; do
        if [[ $line =~ ^Monitor\ $monitor_name\ \(ID ]]; then
            in_monitor_section=true
        elif [[ $line =~ ^Monitor\ [^[:space:]]+\ \(ID ]] && [[ $in_monitor_section == true ]]; then
            in_monitor_section=false
        elif [[ $in_monitor_section == true && $line =~ ^[[:space:]]*availableModes: ]]; then
            local modes_line="${line#*availableModes: }"
            
            while [[ $modes_line =~ ([0-9]+x[0-9]+)@([0-9]+\.[0-9]+)Hz ]]; do
                local resolution="${BASH_REMATCH[1]}"
                local width=$(echo "$resolution" | cut -d'x' -f1)
                local height=$(echo "$resolution" | cut -d'x' -f2)
                local pixels=$((width * height))
                
                if [[ $pixels -gt $max_pixels ]]; then
                    best_resolution="$resolution"
                    max_pixels=$pixels
                fi
                
                modes_line="${modes_line#*${BASH_REMATCH[0]}}"
            done
            break
        fi
    done <<< "$hypr_output"
    
    local max_refresh=$(get_max_refresh_rate "$monitor_name" "$best_resolution")
    echo "$best_resolution@$max_refresh"
}

# Detect connected monitors
detect_monitors() {
    if ! command -v hyprctl &>/dev/null || ! hyprctl monitors &>/dev/null 2>&1; then
        log_error "Cannot detect monitors (Hyprland not running or not installed)"
        return 1
    fi
    
    local monitors=()
    while IFS= read -r line; do
        if [[ $line =~ ^Monitor\ ([^[:space:]]+)\ \(ID ]]; then
            local monitor_name="${BASH_REMATCH[1]}"
            local best_mode=$(get_monitor_best_mode "$monitor_name")
            monitors+=("$monitor_name:$best_mode")
        fi
    done <<< "$(hyprctl monitors 2>/dev/null)"
    
    printf '%s\n' "${monitors[@]}"
}

# Generate monitor configuration
generate_monitor_config() {
    local monitors=("$@")
    local device_type=$(detect_device_type)
    local x_offset=0
    
    echo "# Auto-generated monitor configuration"
    echo "# Generated on $(date)"
    echo "# Device type: $device_type"
    echo ""
    
    # Device-specific scaling
    local laptop_scale="1.25"
    local desktop_scale="1"
    
    # Separate built-in and external monitors
    local builtin_monitors=()
    local external_monitors=()
    
    for info in "${monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        if [[ "$monitor_name" =~ ^(eDP|LVDS|DSI) ]]; then
            builtin_monitors+=("$info")
        else
            external_monitors+=("$info")
        fi
    done
    
    # Configure built-in monitors first
    for info in "${builtin_monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        local mode_info=$(echo "$info" | cut -d':' -f2)
        local resolution=$(echo "$mode_info" | cut -d'@' -f1)
        local refresh_rate=$(echo "$mode_info" | cut -d'@' -f2)
        
        echo "monitor = $monitor_name,$resolution@$refresh_rate,${x_offset}x0,$laptop_scale"
        
        local width=$(echo "$resolution" | cut -d'x' -f1)
        x_offset=$((x_offset + width))
    done
    
    # Configure external monitors
    local ext_scale="$desktop_scale"
    [[ "$device_type" == "laptop" ]] && ext_scale="$laptop_scale"
    
    for info in "${external_monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        local mode_info=$(echo "$info" | cut -d':' -f2)
        local resolution=$(echo "$mode_info" | cut -d'@' -f1)
        local refresh_rate=$(echo "$mode_info" | cut -d'@' -f2)
        
        echo "monitor = $monitor_name,$resolution@$refresh_rate,${x_offset}x0,$ext_scale"
        
        local width=$(echo "$resolution" | cut -d'x' -f1)
        x_offset=$((x_offset + width))
    done
    
    # Fallback
    echo ""
    echo "# Fallback for unrecognized monitors"
    echo "monitor = ,preferred,auto,$desktop_scale"
}

# Setup Hyprland monitors
hyprland_setup() {
    log_section "Hyprland Monitor Setup"
    
    check_hyprland || return 1
    
    local device_type=$(detect_device_type)
    log_info "Detected device: $device_type"
    
    echo
    log_info "Detecting monitors..."
    
    local monitors=($(detect_monitors))
    
    # Ensure directory exists
    ensure_directory "$(dirname "$MONITORS_CONF")"
    
    if [[ ${#monitors[@]} -eq 0 ]]; then
        log_warning "No monitors detected (Hyprland not running?)"
        
        # Use template as fallback
        local template_file="$DOTFILES_DIR/stow/hypr/.config/hypr/monitors.conf.template"
        if [[ -f "$template_file" ]]; then
            log_info "Using template fallback..."
            cp "$template_file" "$MONITORS_CONF"
            log_success "Monitor configuration created from template"
        else
            # Create basic fallback
            {
                echo "# Fallback monitor configuration"
                echo "# Run 'dotfiles hyprland setup' after starting Hyprland"
                echo ""
                echo "monitor = ,preferred,auto,1"
            } > "$MONITORS_CONF"
            log_success "Created fallback monitor configuration"
        fi
        return 0
    fi
    
    log_info "Detected monitors:"
    for info in "${monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        local mode_info=$(echo "$info" | cut -d':' -f2)
        echo "  • $monitor_name: $mode_info"
    done
    
    echo

    # Generate and write config
    log_info "Generating monitor configuration..."
    generate_monitor_config "${monitors[@]}" > "$MONITORS_CONF"
    log_success "Monitor configuration written to monitors.conf"

    # Update main config to source monitors.conf
    local main_config="$HOME/.config/hypr/hyprland.conf"
    if [[ -f "$main_config" ]] && ! grep -q "source.*monitors\.conf" "$main_config"; then
        echo -e "\n# Device-specific monitor configuration\nsource = ~/.config/hypr/monitors.conf" >> "$main_config"
        log_info "Added monitors.conf to hyprland.conf"
    fi

    # Reload if Hyprland is running
    if hyprctl version &>/dev/null; then
        echo
        log_info "Reloading Hyprland (screen may flash briefly)..."
        sleep 0.5
        hyprctl reload 2>/dev/null && log_success "Configuration reloaded" || log_warning "Failed to reload"
        # Give time for screen to stabilize
        sleep 1.5
    fi
}

# Show Hyprland status
hyprland_status() {
    local skip_title="${1:-}"
    [[ -z "$skip_title" ]] && log_section "Hyprland Status"

    if ! command -v hyprctl &>/dev/null; then
        log_error "Hyprland is not installed"
        log_info "Install Hyprland to use this feature"
        return 1
    fi

    # Check if running
    if ! hyprctl version &>/dev/null 2>&1; then
        log_warning "Hyprland is not running"
        log_info "Start Hyprland to see full status details"
        return 0
    fi

    # Show monitors with better formatting
    log_info "Monitors:"
    local monitor_count=0
    local current_monitor=""
    local current_res=""
    local current_refresh=""

    while IFS= read -r line; do
        # Monitor name line: "Monitor eDP-1 (ID 0):"
        if [[ $line =~ ^Monitor\ ([^[:space:]]+)\ \(ID ]]; then
            current_monitor="${BASH_REMATCH[1]}"
        # Resolution line: "  1920x1080@60.00000 at 0x0"
        elif [[ $line =~ ^[[:space:]]+([0-9]+x[0-9]+)@([0-9]+\.[0-9]+) ]]; then
            current_res="${BASH_REMATCH[1]}"
            current_refresh=$(printf "%.0f" "${BASH_REMATCH[2]}")
            echo "$(status_info) $current_monitor $(gum style --foreground 8 "$current_res @ ${current_refresh}Hz")"
            ((monitor_count++))
        fi
    done < <(hyprctl monitors 2>/dev/null)

    if [[ $monitor_count -eq 0 ]]; then
        echo "  $(gum style --foreground 8 "No monitors detected")"
    fi

    echo

    # Show plugin status
    if command -v hyprpm &>/dev/null; then
        source "$DOTFILES_DIR/lib/hyprland-plugins.sh"
        load_plugin_config

        if [[ ${#HYPRLAND_PLUGINS[@]} -gt 0 ]]; then
            log_info "Plugins:"
            local enabled_count=0
            local missing_count=0

            for plugin_name in "${!HYPRLAND_PLUGINS[@]}"; do
                if is_plugin_enabled "$plugin_name"; then
                    echo "$(status_ok) $plugin_name"
                    ((enabled_count++))
                else
                    echo "$(status_warning) $plugin_name (not enabled)"
                    ((missing_count++))
                fi
            done
            echo

        else
            log_info "No plugins configured"
            echo
        fi
    else
        log_info "hyprpm not found - plugin management unavailable"
        echo
    fi

    # Show configuration status
    log_info "Configuration:"
    local hypr_config="$HOME/.config/hypr/hyprland.conf"
    if [[ -f "$hypr_config" ]]; then
        echo "$(status_ok) Main config: $hypr_config"
    else
        echo "$(status_warning) Main config: not found"
    fi

    # Check for config includes
    local config_dir="$HOME/.config/hypr"
    if [[ -d "$config_dir" ]]; then
        local config_files=$(find "$config_dir" -name "*.conf" -type f 2>/dev/null | wc -l)
        if [[ $config_files -gt 1 ]]; then
            echo "$(gum style --foreground 8 "$config_files config files found")"
        fi
    fi
}

# Show Hyprland version information
hyprland_show_version() {
    if command -v hyprctl &>/dev/null; then
        local version=$(hyprctl version 2>/dev/null | head -1 | grep -oP 'Hyprland \K\d+\.\d+\.\d+' || echo "unknown")
        show_info "Version" "$version"
    else
        show_info "Status" "not installed"
    fi
}

# Generate GPU-specific configuration
generate_gpu_config() {
    local gpu_conf="$HOME/.config/hypr/gpu.conf"
    local gpu_type=""

    # Detect GPU
    if has_nvidia_gpu; then
        gpu_type="NVIDIA"
    elif has_amd_gpu; then
        gpu_type="AMD"
    elif has_intel_gpu; then
        gpu_type="Intel"
    else
        gpu_type="Unknown"
    fi

    log_info "Detected GPU: $gpu_type"

    # Find the correct DRI devices
    local dri_card=$(ls -1 /dev/dri/card* 2>/dev/null | grep -v 'card0' | head -1 | sed 's|/dev/dri/||')
    local render_device=$(ls -1 /dev/dri/renderD* 2>/dev/null | head -1 | sed 's|/dev/dri/||')

    # Fallback to card0 if no other card found
    [[ -z "$dri_card" ]] && dri_card="card0"
    [[ -z "$render_device" ]] && render_device="renderD128"

    # Backup existing gpu.conf
    if [[ -f "$gpu_conf" ]]; then
        cp "$gpu_conf" "${gpu_conf}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backed up existing gpu.conf"
    fi

    # Generate header
    cat > "$gpu_conf" << EOF
# ================================
# GPU-SPECIFIC CONFIGURATION
# ================================
# Auto-generated on $(date)
# Detected GPU: $gpu_type
# DRI card: /dev/dri/$dri_card
# Render device: /dev/dri/$render_device

EOF

    # Add GPU-specific settings
    if [[ "$gpu_type" == "NVIDIA" ]]; then
        cat >> "$gpu_conf" << EOF
# ================================
# NVIDIA GPU SETTINGS
# ================================
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = LIBVA_DRIVER_NAME,nvidia
env = NVIDIA_WAYLAND_ENABLE_DRM_KMS,1
env = __GL_GSYNC_ALLOWED,0
env = __GL_VRR_ALLOWED,0

# NVIDIA suspend/resume fixes
env = __GL_MaxFramesAllowed,1
env = __GL_SYNC_TO_VBLANK,0
env = NVIDIA_FORCE_COMPOSITION_PIPELINE,1
env = __GL_THREADED_OPTIMIZATIONS,0

# WLR settings for NVIDIA
env = WLR_NO_HARDWARE_CURSORS,1
env = WLR_RENDERER,vulkan
env = WLR_DRM_DEVICES,/dev/dri/${dri_card}
env = WLR_RENDER_DRM_DEVICE,/dev/dri/${render_device}
EOF
    elif [[ "$gpu_type" == "AMD" ]]; then
        cat >> "$gpu_conf" << EOF
# ================================
# AMD GPU SETTINGS
# ================================
# Hardware video acceleration
env = LIBVA_DRIVER_NAME,radeonsi
env = VDPAU_DRIVER,radeonsi

# WLR settings for AMD
env = WLR_RENDERER,vulkan
env = WLR_DRM_DEVICES,/dev/dri/${dri_card}
env = WLR_RENDER_DRM_DEVICE,/dev/dri/${render_device}

# Mesa/AMD optimizations
env = MESA_SHADER_CACHE_DISABLE,false
env = RADV_PERFTEST,gpl,nggc,sam
env = AMD_VULKAN_ICD,RADV
EOF
    elif [[ "$gpu_type" == "Intel" ]]; then
        cat >> "$gpu_conf" << EOF
# ================================
# INTEL GPU SETTINGS
# ================================
# Hardware video acceleration
env = LIBVA_DRIVER_NAME,iHD
env = VDPAU_DRIVER,va_gl

# WLR settings for Intel
env = WLR_RENDERER,vulkan
env = WLR_DRM_DEVICES,/dev/dri/${dri_card}
env = WLR_RENDER_DRM_DEVICE,/dev/dri/${render_device}
EOF
    else
        cat >> "$gpu_conf" << EOF
# ================================
# GENERIC GPU SETTINGS
# ================================
env = WLR_RENDERER,vulkan
EOF
    fi

    log_success "Generated gpu.conf for $gpu_type"
    log_info "DRI card: /dev/dri/$dri_card"
    log_info "Render device: /dev/dri/$render_device"
}

# Setup GPU configuration
hyprland_setup_gpu() {
    log_section "GPU Configuration Setup"

    # Ensure directory exists
    ensure_directory "$HOME/.config/hypr"

    generate_gpu_config

    # Update hyprland.conf to source gpu.conf if not already there
    local main_config="$HOME/.config/hypr/hyprland.conf"
    if [[ -f "$main_config" ]] && ! grep -q "source.*gpu\.conf" "$main_config"; then
        # Add before other sources to ensure GPU settings load first
        if grep -q "^source = " "$main_config"; then
            # Insert before the first source line
            sed -i '0,/^source = /{s/^source = /source = ~\/.config\/hypr\/gpu.conf\n&/}' "$main_config"
        else
            # Add at the beginning of the file after comments
            sed -i '1a source = ~/.config/hypr/gpu.conf' "$main_config"
        fi
        log_success "Added gpu.conf to hyprland.conf"
    elif [[ -f "$main_config" ]]; then
        log_info "gpu.conf already sourced in hyprland.conf"
    fi

    echo
    log_warning "You need to restart Hyprland for GPU changes to take effect"
    log_info "Log out and log back in, or restart your system"
}

# Setup Hyprland with plugins and monitors
hyprland_setup_all() {
    # Setup GPU configuration first
    hyprland_setup_gpu
    echo

    if command -v hyprpm &>/dev/null; then
        source "$DOTFILES_DIR/lib/hyprland-plugins.sh"
        setup_hyprland_plugins
        echo
    fi
    hyprland_setup
}

# Hyprland management menu
hyprland_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"

    while true; do
        clear_screen "Hyprland"
        hyprland_show_version
        echo

        local action=$(choose_option \
            "Setup Hyprland" \
            "Show details" \
            "Back")

        [[ -z "$action" ]] && return

        case "$action" in
            "Setup Hyprland")
                run_operation "" hyprland_setup_all
                ;;
            "Show details")
                run_operation "" hyprland_status
                ;;
            "Back")
                return
                ;;
        esac
    done
}

