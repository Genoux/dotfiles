#!/bin/bash

# setup-hyprland.sh - Hyprland monitor configuration
# Internal worker script - called by dotfiles.sh to configure monitors for this system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Monitor configuration paths
MONITORS_CONF="$HOME/.config/hypr/monitors.conf"

# Simple flag parsing
FORCE=false
QUIET=false

for arg in "$@"; do
    case $arg in
        --force) FORCE=true ;;
        --quiet) QUIET=true ;;
    esac
done

# Check if Hyprland is available
check_hyprland() {
    if ! has_command hyprctl; then
        log_error "Hyprland not found. Install it first via package manager."
        return 1
    fi
    return 0
}

# Detect device type (laptop vs desktop)
detect_device_type() {
    # Check for laptop built-in display names
    if has_command hyprctl && hyprctl monitors &>/dev/null; then
        if hyprctl monitors 2>/dev/null | grep -qE "Monitor (eDP|LVDS|DSI)"; then
            echo "laptop"
            return
        fi
    fi
    
    # Fallback: check xrandr
    if has_command xrandr; then
        if xrandr 2>/dev/null | grep -qE "(eDP|LVDS|DSI).*connected"; then
            echo "laptop"
            return
        fi
    fi
    
    # Check for battery (laptop indicator)
    if [[ -d /sys/class/power_supply/BAT* ]]; then
        echo "laptop"
        return
    fi
    
    echo "desktop"
}

# Get maximum refresh rate for a monitor resolution from hyprctl
get_max_refresh_rate() {
    local monitor_name="$1"
    local target_resolution="$2"
    local max_refresh=60.0
    
    # Use hyprctl to get available modes
    if has_command hyprctl && hyprctl monitors &>/dev/null; then
        local hypr_output=$(hyprctl monitors 2>/dev/null)
        local in_monitor_section=false
        local in_modes_section=false
        
        while IFS= read -r line; do
            if [[ $line =~ ^Monitor\ $monitor_name\ \(ID ]]; then
                in_monitor_section=true
                in_modes_section=false
            elif [[ $line =~ ^Monitor\ [^[:space:]]+\ \(ID ]] && [[ $in_monitor_section == true ]]; then
                in_monitor_section=false
                in_modes_section=false
            elif [[ $in_monitor_section == true && $line =~ ^[[:space:]]*availableModes: ]]; then
                in_modes_section=true
                # Extract modes from the same line
                local modes_line="${line#*availableModes: }"
                # Parse all modes for our target resolution
                while [[ $modes_line =~ $target_resolution@([0-9]+\.[0-9]+)Hz ]]; do
                    local refresh_rate="${BASH_REMATCH[1]}"
                    # Check if this is higher than our current max
                    local refresh_int=$(echo "$refresh_rate" | sed 's/\.//' | sed 's/^0*//' | sed 's/^$/0/')
                    local max_int=$(echo "$max_refresh" | sed 's/\.//' | sed 's/^0*//' | sed 's/^$/0/')
                    if [[ $refresh_int -gt $max_int ]]; then
                        max_refresh="$refresh_rate"
                    fi
                    # Remove the matched part and continue
                    modes_line="${modes_line#*${BASH_REMATCH[0]}}"
                done
            fi
        done <<< "$hypr_output"
    fi
    
    echo "$max_refresh"
}

# Get preferred resolution and maximum refresh rate for a monitor
get_monitor_best_mode() {
    local monitor_name="$1"
    local best_resolution="1920x1080"
    local max_refresh="60.0"
    
    # Use hyprctl to get available modes and find the best one
    if has_command hyprctl && hyprctl monitors &>/dev/null; then
        local hypr_output=$(hyprctl monitors 2>/dev/null)
        local in_monitor_section=false
        local max_pixels=0
        
        while IFS= read -r line; do
            if [[ $line =~ ^Monitor\ $monitor_name\ \(ID ]]; then
                in_monitor_section=true
            elif [[ $line =~ ^Monitor\ [^[:space:]]+\ \(ID ]] && [[ $in_monitor_section == true ]]; then
                in_monitor_section=false
            elif [[ $in_monitor_section == true && $line =~ ^[[:space:]]*availableModes: ]]; then
                # Extract modes from the same line
                local modes_line="${line#*availableModes: }"
                
                # Parse all available modes to find the best resolution
                while [[ $modes_line =~ ([0-9]+x[0-9]+)@([0-9]+\.[0-9]+)Hz ]]; do
                    local resolution="${BASH_REMATCH[1]}"
                    local refresh_rate="${BASH_REMATCH[2]}"
                    
                    # Calculate total pixels
                    local width=$(echo "$resolution" | cut -d'x' -f1)
                    local height=$(echo "$resolution" | cut -d'x' -f2)
                    local pixels=$((width * height))
                    
                    # If this resolution has more pixels, use it
                    if [[ $pixels -gt $max_pixels ]]; then
                        best_resolution="$resolution"
                        max_pixels=$pixels
                    fi
                    
                    # Remove the matched part and continue
                    modes_line="${modes_line#*${BASH_REMATCH[0]}}"
                done
                break
            fi
        done <<< "$hypr_output"
    fi
    
    # Get maximum refresh rate for the best resolution
    max_refresh=$(get_max_refresh_rate "$monitor_name" "$best_resolution")
    
    echo "$best_resolution@$max_refresh"
}

# Detect connected monitors with enhanced capabilities and maximum refresh rates
detect_monitors_enhanced() {
    local monitor_info=()
    
    if has_command hyprctl && hyprctl monitors &>/dev/null; then
        # Get all monitor names first
        local monitor_names=()
        while IFS= read -r line; do
            if [[ $line =~ ^Monitor\ ([^[:space:]]+)\ \(ID ]]; then
                monitor_names+=("${BASH_REMATCH[1]}")
            fi
        done <<< "$(hyprctl monitors 2>/dev/null)"
        
        # For each monitor, get the best mode with maximum refresh rate
        for monitor_name in "${monitor_names[@]}"; do
            local best_mode=$(get_monitor_best_mode "$monitor_name")
            monitor_info+=("$monitor_name:$best_mode")
        done
    fi
    
    # Return monitor info array
    printf '%s\n' "${monitor_info[@]}"
}

# Generate monitor configuration with device-specific scaling
generate_monitor_config() {
    local monitor_info=("$@")
    local device_type=$(detect_device_type)
    local config=""
    local x_offset=0
    
    config+="# Auto-generated monitor configuration with maximum refresh rates\n"
    config+="# Generated on $(date)\n"
    config+="# Device type: $device_type\n"
    config+="# Uses highest resolution and maximum refresh rate for each monitor\n"
    config+="# Only monitors are device-specific - input/appearance stay universal\n\n"
    
    # Device-specific scaling
    local laptop_scale="1.25"  # 25% larger for laptop readability
    local desktop_scale="1"    # No scaling for desktop
    
    # Separate built-in and external monitors
    local builtin_monitors=()
    local external_monitors=()
    
    for info in "${monitor_info[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        if [[ "$monitor_name" =~ ^(eDP|LVDS|DSI) ]]; then
            builtin_monitors+=("$info")
        else
            external_monitors+=("$info")
        fi
    done
    
    # Configure built-in monitors first (with laptop scaling)
    for info in "${builtin_monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        local mode_info=$(echo "$info" | cut -d':' -f2)
        
        if [[ "$mode_info" == "preferred" ]]; then
            config+="monitor = $monitor_name,preferred,${x_offset}x0,$laptop_scale\n"
            x_offset=$((x_offset + 1920))
        else
            local resolution=$(echo "$mode_info" | cut -d'@' -f1)
            local refresh_rate=$(echo "$mode_info" | cut -d'@' -f2)
            
            config+="monitor = $monitor_name,$resolution@$refresh_rate,${x_offset}x0,$laptop_scale\n"
            
            local width=$(echo "$resolution" | cut -d'x' -f1)
            x_offset=$((x_offset + width))
        fi
    done
    
    # Configure external monitors (with appropriate scaling)
    local ext_scale="$desktop_scale"
    if [[ "$device_type" == "laptop" ]]; then
        ext_scale="$laptop_scale"  # Use laptop scaling for external monitors on laptops too
    fi
    
    for info in "${external_monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        local mode_info=$(echo "$info" | cut -d':' -f2)
        
        if [[ "$mode_info" == "preferred" ]]; then
            config+="monitor = $monitor_name,preferred,${x_offset}x0,$ext_scale\n"
            x_offset=$((x_offset + 1920))
        else
            local resolution=$(echo "$mode_info" | cut -d'@' -f1)
            local refresh_rate=$(echo "$mode_info" | cut -d'@' -f2)
            
            config+="monitor = $monitor_name,$resolution@$refresh_rate,${x_offset}x0,$ext_scale\n"
            
            local width=$(echo "$resolution" | cut -d'x' -f1)
            x_offset=$((x_offset + width))
        fi
    done
    
    # Fallback for unknown monitors
    config+="\n# Fallback for unrecognized monitors\n"
    config+="monitor = ,preferred,auto,$desktop_scale\n"
    
    echo -e "$config"
}

# Main execution - setup monitor configuration
if ! check_hyprland; then
    exit 1
fi

device_type=$(detect_device_type)

if [[ "$QUIET" != true ]]; then
    log_section "Hyprland Monitor Setup"
    log_info "Detected device: $device_type"
    echo
fi

# Get monitor information with maximum refresh rates
if [[ "$QUIET" != true ]]; then
    log_info "Detecting monitors and maximum refresh rates..."
fi

monitor_info=($(detect_monitors_enhanced))

if [[ ${#monitor_info[@]} -eq 0 ]]; then
    log_error "No monitors detected"
    exit 1
fi

if [[ "$QUIET" != true ]]; then
    log_info "Detected monitors with optimal settings:"
    for info in "${monitor_info[@]}"; do
        monitor_name=$(echo "$info" | cut -d':' -f1)
        mode_info=$(echo "$info" | cut -d':' -f2)
        log_info "  $monitor_name: $mode_info"
    done
fi

# Generate configuration
config=$(generate_monitor_config "${monitor_info[@]}")

# Ensure directory exists
ensure_dir "$(dirname "$MONITORS_CONF")"

# Write new config
echo -e "$config" > "$MONITORS_CONF"
log_success "Monitor configuration written to $(basename "$MONITORS_CONF")"

# Update main config to include monitors.conf if needed
main_config="$HOME/.config/hypr/hyprland.conf"
if [[ -f "$main_config" ]] && ! grep -q "source.*monitors\.conf" "$main_config"; then
    echo -e "\n# Device-specific monitor configuration\nsource = ~/.config/hypr/monitors.conf" >> "$main_config"
    [[ "$QUIET" != true ]] && log_info "Added monitors.conf include to hyprland.conf"
fi


# Reload if Hyprland is running
if has_command hyprctl && hyprctl version &>/dev/null; then
    if [[ "$QUIET" != true ]]; then
        echo
        log_info "Reloading Hyprland configuration..."
    fi
    hyprctl reload 2>/dev/null && log_success "Configuration reloaded" || log_warning "Failed to reload"
elif [[ "$QUIET" != true ]]; then
    echo
    log_info "Start Hyprland to apply monitor configuration"
fi 