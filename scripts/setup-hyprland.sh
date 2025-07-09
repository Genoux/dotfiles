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

# Detect connected monitors with enhanced capabilities
detect_monitors_enhanced() {
    local monitor_info=()
    
    if has_command hyprctl && hyprctl monitors &>/dev/null; then
        # Parse hyprctl for detailed monitor info
        local current_monitor=""
        local current_resolution=""
        local current_refresh=""
        
        while IFS= read -r line; do
            if [[ $line =~ ^Monitor\ ([^[:space:]]+)\ \(ID ]]; then
                if [[ -n "$current_monitor" ]]; then
                    monitor_info+=("$current_monitor:$current_resolution@$current_refresh")
                fi
                current_monitor="${BASH_REMATCH[1]}"
                current_resolution=""
                current_refresh=""
            elif [[ -n "$current_monitor" && $line =~ ^[[:space:]]+([0-9]+x[0-9]+)@([0-9]+\.[0-9]+) ]]; then
                current_resolution="${BASH_REMATCH[1]}"
                current_refresh="${BASH_REMATCH[2]}"
            fi
        done <<< "$(hyprctl monitors 2>/dev/null)"
        
        # Save last monitor
        if [[ -n "$current_monitor" ]]; then
            monitor_info+=("$current_monitor:$current_resolution@$current_refresh")
        fi
    else
        # Fallback detection
        while IFS= read -r line; do
            if [[ $line =~ ^([^[:space:]]+)\ connected ]]; then
                monitor_info+=("${BASH_REMATCH[1]}:preferred")
            fi
        done <<< "$(xrandr 2>/dev/null)"
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
    
    config+="# Auto-generated monitor configuration\n"
    config+="# Generated on $(date)\n"
    config+="# Device type: $device_type\n"
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

# Get monitor information
monitor_info=($(detect_monitors_enhanced))

if [[ ${#monitor_info[@]} -eq 0 ]]; then
    log_error "No monitors detected"
    exit 1
fi

[[ "$QUIET" != true ]] && log_info "Detected monitors: $(echo "${monitor_info[@]}" | cut -d':' -f1 | tr '\n' ' ')"

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