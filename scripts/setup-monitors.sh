#!/bin/bash

# setup-monitors.sh - Automatically detect and configure monitors for Hyprland
# This script detects connected monitors and generates optimal monitor configuration

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
MONITORS_CONF="$DOTFILES_DIR/stow/hypr/.config/hypr/monitors.conf"

# Function to detect if we're on a laptop (has built-in screen)
detect_device_type() {
    # Check for common laptop built-in display names in hyprctl output
    if command -v hyprctl &> /dev/null && hyprctl monitors &>/dev/null; then
        if hyprctl monitors 2>/dev/null | grep -qE "Monitor (eDP|LVDS|DSI)"; then
            echo "laptop"
            return
        fi
    fi
    
    # Fallback: check xrandr or system info
    if command -v xrandr &> /dev/null; then
        if xrandr 2>/dev/null | grep -qE "(eDP|LVDS|DSI).*connected"; then
            echo "laptop"
            return
        fi
    fi
    
    # Check for laptop indicators in DMI
    if [[ -f /sys/class/dmi/id/chassis_type ]]; then
        local chassis_type=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "")
        # Chassis types: 8=Portable, 9=Laptop, 10=Notebook, 14=Sub Notebook
        if [[ "$chassis_type" =~ ^(8|9|10|14)$ ]]; then
            echo "laptop"
            return
        fi
    fi
    
    echo "desktop"
}

# Function to get connected monitors with their capabilities
get_monitor_info() {
    local -A monitors
    local temp_file="/tmp/monitor_info_$$"
    
    if command -v hyprctl &> /dev/null && hyprctl monitors &>/dev/null; then
        # Parse hyprctl monitors output
        hyprctl monitors 2>/dev/null > "$temp_file"
        
        local current_monitor=""
        local current_resolution=""
        local current_refresh=""
        local available_modes=""
        
        while IFS= read -r line; do
            # Match monitor name line: "Monitor DP-1 (ID 0):"
            if [[ $line =~ ^Monitor\ ([^[:space:]]+)\ \(ID ]]; then
                # Save previous monitor if exists
                if [[ -n "$current_monitor" && -n "$current_resolution" && -n "$current_refresh" ]]; then
                    monitors["$current_monitor"]="${current_resolution}@${current_refresh}Hz"
                fi
                
                current_monitor="${BASH_REMATCH[1]}"
                current_resolution=""
                current_refresh=""
                available_modes=""
            # Match current resolution line: "        1920x1080@144.00101 at 0x0"
            elif [[ -n "$current_monitor" && $line =~ ^[[:space:]]+([0-9]+x[0-9]+)@([0-9]+\.[0-9]+)[[:space:]] ]]; then
                current_resolution="${BASH_REMATCH[1]}"
                current_refresh="${BASH_REMATCH[2]}"
            # Match available modes line: "        availableModes: 1920x1080@60.00Hz 1920x1080@144.00Hz ..."
            elif [[ -n "$current_monitor" && $line =~ availableModes:\ (.+) ]]; then
                available_modes="${BASH_REMATCH[1]}"
                # Find highest refresh rate mode for current resolution
                local best_mode=""
                local highest_refresh=0
                
                for mode in $available_modes; do
                    if [[ $mode =~ ^([0-9]+x[0-9]+)@([0-9]+\.[0-9]+)Hz$ ]]; then
                        local mode_res="${BASH_REMATCH[1]}"
                        local mode_refresh="${BASH_REMATCH[2]}"
                        local refresh_int=$(echo "$mode_refresh" | cut -d'.' -f1)
                        
                        # If we don't have a current resolution, use the highest resolution with highest refresh
                        if [[ -z "$current_resolution" ]]; then
                            if [[ $refresh_int -gt $highest_refresh ]]; then
                                best_mode="$mode"
                                highest_refresh=$refresh_int
                            fi
                        # If this mode matches current resolution and has higher refresh, use it
                        elif [[ "$mode_res" == "$current_resolution" && $refresh_int -gt $highest_refresh ]]; then
                            best_mode="$mode"
                            highest_refresh=$refresh_int
                        fi
                    fi
                done
                
                # Use best mode if found and current refresh is not already the highest
                if [[ -n "$best_mode" ]]; then
                    if [[ $best_mode =~ ^([0-9]+x[0-9]+)@([0-9]+\.[0-9]+)Hz$ ]]; then
                        current_resolution="${BASH_REMATCH[1]}"
                        current_refresh="${BASH_REMATCH[2]}"
                    fi
                fi
            fi
        done < "$temp_file"
        
        # Save last monitor
        if [[ -n "$current_monitor" && -n "$current_resolution" && -n "$current_refresh" ]]; then
            monitors["$current_monitor"]="${current_resolution}@${current_refresh}Hz"
        fi
        
        rm -f "$temp_file"
    else
        echo -e "${YELLOW}⚠️  hyprctl not available, using fallback detection${NC}" >&2
        
        # Fallback to xrandr if available
        if command -v xrandr &> /dev/null; then
            while IFS= read -r line; do
                if [[ $line =~ ^([^[:space:]]+)\ connected.*[[:space:]]([0-9]+x[0-9]+)\+.*[[:space:]]([0-9]+\.[0-9]+)Hz ]]; then
                    local monitor_name="${BASH_REMATCH[1]}"
                    local resolution="${BASH_REMATCH[2]}"
                    local refresh="${BASH_REMATCH[3]}"
                    monitors["$monitor_name"]="${resolution}@${refresh}Hz"
                fi
            done <<< "$(xrandr 2>/dev/null || echo "")"
        fi
        
        # If no monitors detected, add sensible defaults
        if [[ ${#monitors[@]} -eq 0 ]]; then
            local device_type=$(detect_device_type)
            if [[ "$device_type" == "laptop" ]]; then
                monitors["eDP-1"]="preferred"
            else
                monitors["DP-1"]="preferred"
                monitors["HDMI-A-1"]="preferred"
            fi
        fi
    fi
    
    # Output monitor data for further processing
    for monitor in "${!monitors[@]}"; do
        echo "$monitor:${monitors[$monitor]}"
    done
}

# Function to generate monitor configuration
generate_monitor_config() {
    local monitor_info=("$@")
    local device_type=$(detect_device_type)
    local config_content=""
    local x_offset=0
    local primary_set=false
    
    config_content+="# Auto-generated monitor configuration for Hyprland\n"
    config_content+="# Generated on $(date)\n"
    config_content+="# Device type: $device_type\n"
    config_content+="# See https://wiki.hyprland.org/Configuring/Monitors/\n\n"
    
    # Sort monitors: built-in displays first, then external by name
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
    
    # Sort external monitors alphabetically for consistency
    IFS=$'\n' external_monitors=($(sort <<<"${external_monitors[*]}"))
    unset IFS
    
    # Configure built-in monitors first (laptops)
    for info in "${builtin_monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        local mode_info=$(echo "$info" | cut -d':' -f2)
        
        if [[ "$mode_info" == "preferred" ]]; then
            config_content+="monitor = $monitor_name,preferred,${x_offset}x0,1\n"
            x_offset=$((x_offset + 1920)) # Assume 1920 width for preferred
        else
            local resolution=$(echo "$mode_info" | cut -d'@' -f1)
            local refresh_rate=$(echo "$mode_info" | cut -d'@' -f2 | sed 's/Hz//')
            
            config_content+="monitor = $monitor_name,$resolution@$refresh_rate,${x_offset}x0,1\n"
            
            # Update x_offset with actual width
            local width=$(echo "$resolution" | cut -d'x' -f1)
            x_offset=$((x_offset + width))
        fi
        primary_set=true
    done
    
    # Configure external monitors
    for info in "${external_monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        local mode_info=$(echo "$info" | cut -d':' -f2)
        
        if [[ "$mode_info" == "preferred" ]]; then
            if [[ "$device_type" == "desktop" && "$primary_set" == "false" ]]; then
                config_content+="monitor = $monitor_name,preferred,0x0,1\n"
                primary_set=true
            else
                config_content+="monitor = $monitor_name,preferred,auto-right,1\n"
            fi
        else
            local resolution=$(echo "$mode_info" | cut -d'@' -f1)
            local refresh_rate=$(echo "$mode_info" | cut -d'@' -f2 | sed 's/Hz//')
            
            # Enable VRR for high refresh rate monitors (120Hz+)
            local vrr_option=""
            local refresh_int=$(echo "$refresh_rate" | cut -d'.' -f1)
            if [[ $refresh_int -ge 120 ]]; then
                vrr_option=",vrr,1"
            fi
            
            # Position: first external monitor on desktop goes to 0x0, others auto-right
            if [[ "$device_type" == "desktop" && "$primary_set" == "false" ]]; then
                config_content+="monitor = $monitor_name,$resolution@$refresh_rate,0x0,1$vrr_option\n"
                primary_set=true
            else
                config_content+="monitor = $monitor_name,$resolution@$refresh_rate,auto-right,1$vrr_option\n"
            fi
        fi
    done
    
    # Add fallback rule for unspecified monitors (recommended by Hyprland docs)
    config_content+="\n# Fallback rule for any unspecified monitors\n"
    config_content+="monitor = ,preferred,auto,1\n"
    
    echo -e "$config_content"
}

# Function to backup existing config
backup_existing_config() {
    if [[ -f "$MONITORS_CONF" ]]; then
        local backup_file="$MONITORS_CONF.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$MONITORS_CONF" "$backup_file"
        echo -e "${YELLOW}📦 Backed up existing config to:${NC} $(basename "$backup_file")"
    fi
}

# Function to write new config
write_monitor_config() {
    local config_content="$1"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$MONITORS_CONF")"
    
    # Write the configuration
    echo -e "$config_content" > "$MONITORS_CONF"
    echo -e "${GREEN}✅ Monitor configuration written to:${NC} $MONITORS_CONF"
}

# Function to reload Hyprland config
reload_hyprland() {
    if command -v hyprctl &> /dev/null && hyprctl version &>/dev/null; then
        echo -e "${BLUE}🔄 Reloading Hyprland configuration...${NC}"
        if hyprctl reload 2>/dev/null; then
            echo -e "${GREEN}✅ Hyprland configuration reloaded${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not reload Hyprland (not running or connection failed)${NC}"
            echo -e "${BLUE}💡 Changes will take effect on next Hyprland restart${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Hyprland not running, changes will take effect on next start${NC}"
    fi
}

# Main function
main() {
    local force=false
    local interactive=true
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force=true
                shift
                ;;
            --quiet|-q)
                interactive=false
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--force] [--quiet]"
                echo "  --force: Skip confirmation prompts"
                echo "  --quiet: Non-interactive mode"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done
    
    echo -e "${BLUE}🖥️  Monitor Auto-Configuration${NC}"
    echo
    
    # Check if monitors.conf exists and warn user
    if [[ -f "$MONITORS_CONF" && "$force" != true && "$interactive" == true ]]; then
        echo -e "${YELLOW}⚠️  Existing monitor configuration found${NC}"
        echo "Current config:"
        grep "^monitor = " "$MONITORS_CONF" 2>/dev/null | sed 's/^/  /' || echo "  (no monitor rules found)"
        echo
        read -p "Replace with auto-detected configuration? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Keeping existing configuration${NC}"
            exit 0
        fi
    fi
    
    # Backup existing config
    backup_existing_config
    
    # Get monitor information
    echo -e "${BLUE}🔍 Detecting connected monitors...${NC}"
    local monitor_data=($(get_monitor_info))
    
    if [[ ${#monitor_data[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No monitors detected${NC}"
        exit 1
    fi
    
    # Display detected monitors
    echo -e "${GREEN}✅ Detected monitors:${NC}"
    for info in "${monitor_data[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        local mode_info=$(echo "$info" | cut -d':' -f2)
        
        if [[ "$mode_info" == "preferred" ]]; then
            echo -e "  ${BLUE}$monitor_name${NC}: ${YELLOW}preferred (auto-detect)${NC}"
        else
            local resolution=$(echo "$mode_info" | cut -d'@' -f1)
            local refresh_rate=$(echo "$mode_info" | cut -d'@' -f2 | sed 's/Hz//')
            
            # Check for VRR eligibility
            local refresh_int=$(echo "$refresh_rate" | cut -d'.' -f1)
            local vrr_note=""
            if [[ $refresh_int -ge 120 ]]; then
                vrr_note=" ${PURPLE}(VRR enabled)${NC}"
            fi
            
            echo -e "  ${BLUE}$monitor_name${NC}: ${GREEN}${resolution}${NC} @ ${PURPLE}${refresh_rate}Hz${NC}${vrr_note}"
        fi
    done
    
    echo
    echo -e "${BLUE}📝 Generating monitor configuration...${NC}"
    
    # Generate configuration
    local config_content=$(generate_monitor_config "${monitor_data[@]}")
    
    # Write configuration
    write_monitor_config "$config_content"
    
    echo
    
    # Reload Hyprland if running
    reload_hyprland
    
    echo
    echo -e "${GREEN}🎉 Monitor configuration complete!${NC}"
    
    if [[ "$interactive" == true ]]; then
        echo
        echo -e "${BLUE}💡 Pro tips:${NC}"
        echo "  • Use 'auto-left/right/up/down' for positioning"
        echo "  • Add ',transform,X' for rotation (0-3, 4-7 for flipped)"
        echo "  • Use 'preferred', 'highres', 'highrr' for automatic resolution"
        echo "  • Edit $MONITORS_CONF for fine-tuning"
    fi
}

# Run main function
main "$@" 