#!/bin/bash
# Hyprland configuration operations

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
MONITORS_LUA="$HOME/.config/hypr/monitors.lua"

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

# Get the EDID description for a monitor (stable across reboots, unlike the connector name)
get_monitor_description() {
    local monitor_name="$1"

    if ! command -v hyprctl &>/dev/null || ! hyprctl monitors all &>/dev/null 2>&1; then
        return
    fi

    local hypr_output=$(hyprctl monitors all 2>/dev/null)
    local in_monitor_section=false

    while IFS= read -r line; do
        if [[ $line =~ ^Monitor\ $monitor_name\ \(ID ]]; then
            in_monitor_section=true
        elif [[ $line =~ ^Monitor\ [^[:space:]]+\ \(ID ]] && [[ $in_monitor_section == true ]]; then
            in_monitor_section=false
        elif [[ $in_monitor_section == true && $line =~ ^[[:space:]]*description: ]]; then
            echo "${line#*description: }"
            return
        fi
    done <<< "$hypr_output"
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
            local description=$(get_monitor_description "$monitor_name")
            monitors+=("$monitor_name|$best_mode|$description")
        fi
    done <<< "$(hyprctl monitors 2>/dev/null)"
    
    printf '%s\n' "${monitors[@]}"
}

# Generate monitor configuration
generate_monitor_config() {
    local monitors=("$@")
    local device_type=$(detect_device_type)
    local x_offset=0
    
    echo "-- Auto-generated monitor configuration"
    echo "-- Generated on $(date)"
    echo "-- Device type: $device_type"
    echo ""
    
    # Device-specific scaling
    local laptop_scale="1.25"
    local desktop_scale="1"
    
    # Separate built-in and external monitors
    local builtin_monitors=()
    local external_monitors=()
    
    for info in "${monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d'|' -f1)
        if [[ "$monitor_name" =~ ^(eDP|LVDS|DSI) ]]; then
            builtin_monitors+=("$info")
        else
            external_monitors+=("$info")
        fi
    done
    
    # Configure built-in monitors first
    for info in "${builtin_monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d'|' -f1)
        local mode_info=$(echo "$info" | cut -d'|' -f2)
        local description=$(echo "$info" | cut -d'|' -f3)
        local resolution=$(echo "$mode_info" | cut -d'@' -f1)
        local refresh_rate=$(echo "$mode_info" | cut -d'@' -f2)
        local output_id="$monitor_name"
        [[ -n "$description" ]] && output_id="desc:$description"

        cat << EOF
hl.monitor({
  output = "$output_id",
  mode = "$resolution@$refresh_rate",
  position = "${x_offset}x0",
  scale = $laptop_scale,
})

EOF
        
        local width=$(echo "$resolution" | cut -d'x' -f1)
        x_offset=$((x_offset + width))
    done
    
    # Configure external monitors
    local ext_scale="$desktop_scale"
    [[ "$device_type" == "laptop" ]] && ext_scale="$laptop_scale"
    
    for info in "${external_monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d'|' -f1)
        local mode_info=$(echo "$info" | cut -d'|' -f2)
        local description=$(echo "$info" | cut -d'|' -f3)
        local resolution=$(echo "$mode_info" | cut -d'@' -f1)
        local refresh_rate=$(echo "$mode_info" | cut -d'@' -f2)
        local output_id="$monitor_name"
        [[ -n "$description" ]] && output_id="desc:$description"

        cat << EOF
hl.monitor({
  output = "$output_id",
  mode = "$resolution@$refresh_rate",
  position = "${x_offset}x0",
  scale = $ext_scale,
})

EOF
        
        local width=$(echo "$resolution" | cut -d'x' -f1)
        x_offset=$((x_offset + width))
    done
    
    # Fallback
    echo "-- Fallback for unrecognized monitors"
    cat << EOF
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = $desktop_scale,
})
EOF
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
    ensure_directory "$(dirname "$MONITORS_LUA")"
    
    if [[ ${#monitors[@]} -eq 0 ]]; then
        log_warning "No monitors detected (Hyprland not running?)"
        
        {
            echo "-- Fallback monitor configuration"
            echo "-- Run 'dotfiles hyprland setup' after starting Hyprland"
            echo ""
            echo "hl.monitor({"
            echo "  output = \"\","
            echo "  mode = \"preferred\","
            echo "  position = \"auto\","
            echo "  scale = 1,"
            echo "})"
        } > "$MONITORS_LUA"
        log_success "Created fallback monitor configuration"
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
    generate_monitor_config "${monitors[@]}" > "$MONITORS_LUA"
    log_success "Monitor configuration written to monitors.lua"

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
            monitor_count=$((monitor_count + 1))
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
                    enabled_count=$((enabled_count + 1))
                else
                    echo "$(status_warning) $plugin_name (not enabled)"
                    missing_count=$((missing_count + 1))
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
    local hypr_config="$HOME/.config/hypr/hyprland.lua"
    if [[ -f "$hypr_config" ]]; then
        echo "$(status_ok) Main config: $hypr_config"
    else
        echo "$(status_warning) Main config: not found"
    fi

    # Check for config includes
    local config_dir="$HOME/.config/hypr"
    if [[ -d "$config_dir" ]]; then
        local config_files=$(find "$config_dir" -name "*.lua" -type f 2>/dev/null | wc -l)
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
    local gpu_lua="$HOME/.config/hypr/gpu.lua"
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

    # Generate header
    cat > "$gpu_lua" << EOF
-- Auto-generated GPU configuration
-- Generated on $(date)
-- Detected GPU: $gpu_type
-- DRI card: /dev/dri/$dri_card
-- Render device: /dev/dri/$render_device

EOF

    # Add GPU-specific settings
    if [[ "$gpu_type" == "NVIDIA" ]]; then
        cat >> "$gpu_lua" << EOF
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("NVIDIA_WAYLAND_ENABLE_DRM_KMS", "1")
hl.env("__GL_GSYNC_ALLOWED", "0")
hl.env("__GL_VRR_ALLOWED", "0")

hl.env("__GL_MaxFramesAllowed", "1")
hl.env("__GL_SYNC_TO_VBLANK", "0")
hl.env("NVIDIA_FORCE_COMPOSITION_PIPELINE", "1")
hl.env("__GL_THREADED_OPTIMIZATIONS", "0")

hl.env("WLR_NO_HARDWARE_CURSORS", "1")
-- Vulkan renderer remains disabled because it causes DPMS off/on crashes on this setup.
-- hl.env("WLR_RENDERER", "vulkan")
hl.env("WLR_DRM_DEVICES", "/dev/dri/${dri_card}")
hl.env("WLR_RENDER_DRM_DEVICE", "/dev/dri/${render_device}")
EOF
    elif [[ "$gpu_type" == "AMD" ]]; then
        cat >> "$gpu_lua" << EOF
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("VDPAU_DRIVER", "radeonsi")

-- Vulkan renderer remains disabled because it causes DPMS off/on crashes on this setup.
-- hl.env("WLR_RENDERER", "vulkan")
hl.env("WLR_DRM_DEVICES", "/dev/dri/${dri_card}")
hl.env("WLR_RENDER_DRM_DEVICE", "/dev/dri/${render_device}")

hl.env("MESA_SHADER_CACHE_DISABLE", "false")
hl.env("AMD_VULKAN_ICD", "RADV")
EOF
    elif [[ "$gpu_type" == "Intel" ]]; then
        cat >> "$gpu_lua" << EOF
hl.env("LIBVA_DRIVER_NAME", "iHD")
hl.env("VDPAU_DRIVER", "va_gl")

-- Vulkan renderer remains disabled because it causes DPMS off/on crashes on this setup.
-- hl.env("WLR_RENDERER", "vulkan")
hl.env("WLR_DRM_DEVICES", "/dev/dri/${dri_card}")
hl.env("WLR_RENDER_DRM_DEVICE", "/dev/dri/${render_device}")
EOF
    else
        cat >> "$gpu_lua" << EOF
-- Vulkan renderer remains disabled because it causes DPMS off/on crashes on this setup.
-- hl.env("WLR_RENDERER", "vulkan")
EOF
    fi

    log_success "Generated gpu.lua for $gpu_type"
    log_info "DRI card: /dev/dri/$dri_card"
    log_info "Render device: /dev/dri/$render_device"
}

# Setup GPU configuration
hyprland_setup_gpu() {
    log_section "GPU Configuration Setup"

    # Ensure directory exists
    ensure_directory "$HOME/.config/hypr"

    generate_gpu_config

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

