#!/bin/bash

# setup-hyprland.sh - Simple Hyprland monitor configuration
# Only handles device-specific monitor setup - everything else stays universal

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

MONITORS_CONF="$HOME/.config/hypr/monitors.conf"

show_help() {
    log_section "Hyprland Monitor Setup"
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo -e "  ${GREEN}setup${NC}       Configure monitors for this system (default)"
    echo -e "  ${GREEN}status${NC}      Check current monitor status"
    echo
    echo "Options:"
    echo "  --force       Skip confirmations"
    echo "  --quiet       Minimal output"
    echo
    echo -e "${YELLOW}💡 Note: Only monitors are device-specific.${NC}"
    echo "   Input, appearance, keybinds stay universal in your dotfiles."
}

# Parse arguments
COMMAND="setup"
FORCE=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        setup|status)
            COMMAND="$1"
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
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

# Show Hyprland monitor status
cmd_status() {
    log_section "Hyprland Monitor Status"
    
    # Check if Hyprland is installed
    if has_command hyprctl; then
        log_success "Hyprland installed: $(hyprctl version 2>/dev/null | head -1 || echo 'Unknown version')"
    else
        log_error "Hyprland not installed"
        return 1
    fi
    
    # Device detection
    local device_type=$(detect_device_type)
    echo -e "${BLUE}🔍 Device Type:${NC} $device_type"
    
    # Check if running
    if hyprctl version &>/dev/null; then
        log_success "Hyprland is running"
        
        # Show monitors
        echo
        echo -e "${BLUE}📺 Current Monitors:${NC}"
        hyprctl monitors 2>/dev/null | grep -E "^Monitor|^\s+[0-9]+x[0-9]+" | sed 's/^/  /'
        
    else
        log_warning "Hyprland not running"
    fi
    
    # Check monitor config file
    echo
    echo -e "${BLUE}📁 Monitor Configuration:${NC}"
    if [[ -f "$MONITORS_CONF" ]]; then
        log_success "monitors.conf exists (generated for this system)"
        echo -e "${BLUE}📄 Current config:${NC}"
        grep "^monitor" "$MONITORS_CONF" 2>/dev/null | sed 's/^/    /' || echo "    (no monitor lines found)"
    else
        log_warning "monitors.conf missing - run setup to generate"
    fi
}

# Setup monitor configuration
cmd_setup() {
    if ! check_hyprland; then
        return 1
    fi
    
    local device_type=$(detect_device_type)
    
    if [[ "$QUIET" != true ]]; then
        log_section "Hyprland Monitor Setup"
        log_info "Detected device: $device_type"
        echo
    fi
    
    # Get monitor information
    local monitor_info=($(detect_monitors_enhanced))
    
    if [[ ${#monitor_info[@]} -eq 0 ]]; then
        log_error "No monitors detected"
        return 1
    fi
    
    [[ "$QUIET" != true ]] && log_info "Detected monitors: $(echo "${monitor_info[@]}" | cut -d':' -f1 | tr '\n' ' ')"
    
    # Generate configuration
    local config=$(generate_monitor_config "${monitor_info[@]}")
    
    # Ensure directory exists
    ensure_dir "$(dirname "$MONITORS_CONF")"
    
    # Backup existing config
    backup_file "$MONITORS_CONF"
    
    # Write new config
    echo -e "$config" > "$MONITORS_CONF"
    log_success "Monitor configuration written to $(basename "$MONITORS_CONF")"
    
    # Update main config to include monitors.conf if needed
    local main_config="$HOME/.config/hypr/hyprland.conf"
    if [[ -f "$main_config" ]] && ! grep -q "source.*monitors\.conf" "$main_config"; then
        backup_file "$main_config"
        echo -e "\n# Device-specific monitor configuration\nsource = ~/.config/hypr/monitors.conf" >> "$main_config"
        [[ "$QUIET" != true ]] && log_info "Added monitors.conf include to hyprland.conf"
    fi
    
    if [[ "$QUIET" != true ]]; then
        echo
        if [[ "$device_type" == "laptop" ]]; then
            echo -e "${YELLOW}💡 Laptop optimizations applied:${NC}"
            echo "  • Built-in display scaled to 1.25x for readability"
            echo "  • External monitors use laptop scaling too"
        else
            echo -e "${YELLOW}💡 Desktop optimizations applied:${NC}"
            echo "  • No scaling (1x) for sharp desktop experience"
            echo "  • Multi-monitor layout optimized"
        fi
        
        echo
        echo -e "${BLUE}📝 Remember:${NC}"
        echo "  • Input/gestures/appearance stay universal in your dotfiles"
        echo "  • Only monitors.conf is generated per system"
        echo "  • Missing config? Just run this script again"
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
}

# Execute command
case "$COMMAND" in
    setup)
        cmd_setup
        ;;
    status)
        cmd_status
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac 