#!/bin/bash

# hypr-config.sh - Unified Hyprland configuration based on device type
# This script detects device type and configures all Hyprland settings optimally

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
HYPR_CONFIG_DIR="$DOTFILES_DIR/stow/hypr/.config/hypr"
MONITORS_CONF="$HYPR_CONFIG_DIR/monitors.conf"
INPUT_CONF="$HYPR_CONFIG_DIR/input.conf"

# Function to detect device type
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
    
    # Check for battery presence (another laptop indicator)
    if [[ -d /sys/class/power_supply/BAT* ]]; then
        echo "laptop"
        return
    fi
    
    echo "desktop"
}

# Function to backup configuration files
backup_config() {
    local config_file="$1"
    local config_name="$2"
    
    if [[ -f "$config_file" ]]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}📦 Backing up $config_name to $(basename "$backup_file")${NC}"
        cp "$config_file" "$backup_file"
    fi
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
        # Fallback detection
        local device_type=$(detect_device_type)
        if [[ "$device_type" == "laptop" ]]; then
            monitors["eDP-1"]="preferred"
        else
            monitors["DP-1"]="preferred"
            monitors["HDMI-A-1"]="preferred"
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
    
    # Determine scale factor based on device type
    local laptop_scale="1.25"  # 25% larger for better laptop readability
    local desktop_scale="1"    # No scaling for desktop monitors
    
    # Configure built-in monitors first (laptops)
    for info in "${builtin_monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        local mode_info=$(echo "$info" | cut -d':' -f2)
        
        if [[ "$mode_info" == "preferred" ]]; then
            config_content+="monitor = $monitor_name,preferred,${x_offset}x0,$laptop_scale\n"
            x_offset=$((x_offset + 1920)) # Assume 1920 width for preferred
        else
            local resolution=$(echo "$mode_info" | cut -d'@' -f1)
            local refresh_rate=$(echo "$mode_info" | cut -d'@' -f2 | sed 's/Hz//')
            
            config_content+="monitor = $monitor_name,$resolution@$refresh_rate,${x_offset}x0,$laptop_scale\n"
            
            # Calculate actual width for offset
            local width=$(echo "$resolution" | cut -d'x' -f1)
            x_offset=$((x_offset + width))
        fi
    done
    
    # Configure external monitors (use desktop scaling)
    for info in "${external_monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        local mode_info=$(echo "$info" | cut -d':' -f2)
        
        if [[ "$mode_info" == "preferred" ]]; then
            config_content+="monitor = $monitor_name,preferred,${x_offset}x0,$desktop_scale\n"
            x_offset=$((x_offset + 1920)) # Assume 1920 width for preferred
        else
            local resolution=$(echo "$mode_info" | cut -d'@' -f1)
            local refresh_rate=$(echo "$mode_info" | cut -d'@' -f2 | sed 's/Hz//')
            
            config_content+="monitor = $monitor_name,$resolution@$refresh_rate,${x_offset}x0,$desktop_scale\n"
            
            # Calculate actual width for offset
            local width=$(echo "$resolution" | cut -d'x' -f1)
            x_offset=$((x_offset + width))
        fi
    done
    
    # Add fallback for unknown monitors (use desktop scaling as default)
    config_content+="\n# Fallback for unknown monitors\n"
    config_content+="monitor = ,preferred,auto,$desktop_scale\n"
    
    echo -e "$config_content" > "$MONITORS_CONF"
}

# Function to ensure laptop scaling environment variables
ensure_laptop_scaling_env() {
    local temp_file="/tmp/env_conf_$$"
    local changes_made=false
    
    if [[ ! -f "$ENV_CONF" ]]; then
        echo "📝 Environment config not found, skipping scaling environment setup"
        return
    fi
    
    cp "$ENV_CONF" "$temp_file"
    
    # Add GTK scaling for laptops (after GTK APPLICATION SETTINGS section)
    if ! grep -q "GDK_SCALE" "$ENV_CONF"; then
        # Find the GTK APPLICATION SETTINGS section and add scaling after it
        if grep -q "# GTK APPLICATION SETTINGS" "$ENV_CONF"; then
            sed -i '/# GTK APPLICATION SETTINGS/,/^$/a\
# GTK scaling for laptop displays\
env = GDK_SCALE,1.25' "$temp_file"
            changes_made=true
        fi
    fi
    
    # Add QT scaling for laptops
    if ! grep -q "QT_SCALE_FACTOR" "$ENV_CONF"; then
        # Add after QT_AUTO_SCREEN_SCALE_FACTOR line
        if grep -q "QT_AUTO_SCREEN_SCALE_FACTOR" "$ENV_CONF"; then
            sed -i '/QT_AUTO_SCREEN_SCALE_FACTOR/a\
env = QT_SCALE_FACTOR,1.25' "$temp_file"
            changes_made=true
        fi
    fi
    
    # Apply changes if any were made
    if [[ "$changes_made" == true ]]; then
        mv "$temp_file" "$ENV_CONF"
        echo "✅ Added laptop scaling environment variables"
    else
        rm -f "$temp_file"
        echo "✅ Laptop scaling environment variables already present"
    fi
}

# Function to ensure desktop scaling environment variables
ensure_desktop_scaling_env() {
    local temp_file="/tmp/env_conf_$$"
    local changes_made=false
    
    if [[ ! -f "$ENV_CONF" ]]; then
        echo "📝 Environment config not found, skipping scaling environment setup"
        return
    fi
    
    cp "$ENV_CONF" "$temp_file"
    
    # Remove or disable laptop scaling variables for desktop
    if grep -q "GDK_SCALE,1.25" "$ENV_CONF"; then
        sed -i '/GDK_SCALE,1.25/d' "$temp_file"
        changes_made=true
    fi
    
    if grep -q "QT_SCALE_FACTOR,1.25" "$ENV_CONF"; then
        sed -i '/QT_SCALE_FACTOR,1.25/d' "$temp_file"
        changes_made=true
    fi
    
    # Apply changes if any were made
    if [[ "$changes_made" == true ]]; then
        mv "$temp_file" "$ENV_CONF"
        echo "✅ Removed laptop scaling environment variables for desktop"
    else
        rm -f "$temp_file"
        echo "✅ Desktop scaling environment is already correct"
    fi
}

# Function to ensure essential laptop settings are present
ensure_laptop_input_settings() {
    local temp_file="/tmp/input_conf_$$"
    local changes_made=false
    
    # If input.conf doesn't exist, create minimal laptop config
    if [[ ! -f "$INPUT_CONF" ]]; then
        echo "📝 Creating minimal laptop input configuration..."
        cat > "$INPUT_CONF" << 'EOF'
# ================================ 
# HYPRLAND INPUT CONFIG
# ================================
# Essential laptop-optimized settings

input {
    # Essential touchpad settings for laptops
    touchpad {
        natural_scroll = true
    }
}

# Essential gesture settings for laptops  
gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
}
EOF
        return
    fi
    
    # Read existing config and ensure minimal laptop settings
    cp "$INPUT_CONF" "$temp_file"
    
    # Ensure natural_scroll = true for laptops
    if ! grep -q "natural_scroll.*true" "$INPUT_CONF"; then
        if grep -q "natural_scroll.*false" "$INPUT_CONF"; then
            sed -i 's/natural_scroll = false/natural_scroll = true/' "$temp_file"
            changes_made=true
        elif grep -q "touchpad {" "$INPUT_CONF"; then
            # Add natural_scroll inside existing touchpad block
            sed -i '/touchpad {/a\        natural_scroll = true' "$temp_file"
            changes_made=true
        fi
    fi
    
    # Ensure workspace_swipe = true for laptops
    if ! grep -q "workspace_swipe.*true" "$INPUT_CONF"; then
        if grep -q "workspace_swipe.*false" "$INPUT_CONF"; then
            sed -i 's/workspace_swipe = false/workspace_swipe = true/' "$temp_file"
            changes_made=true
        elif grep -q "gestures {" "$INPUT_CONF"; then
            # Add workspace_swipe inside existing gestures block
            sed -i '/gestures {/a\    workspace_swipe = true' "$temp_file"
            changes_made=true
        else
            # Add gestures block if it doesn't exist
            echo "" >> "$temp_file"
            echo "# Essential gestures for laptop" >> "$temp_file"
            echo "gestures {" >> "$temp_file"
            echo "    workspace_swipe = true" >> "$temp_file"
            echo "    workspace_swipe_fingers = 3" >> "$temp_file"
            echo "}" >> "$temp_file"
            changes_made=true
        fi
    fi
    
    # Apply changes if any were made
    if [[ "$changes_made" == true ]]; then
        mv "$temp_file" "$INPUT_CONF"
        echo "✅ Updated essential laptop settings in existing config"
    else
        rm -f "$temp_file"
        echo "✅ Essential laptop settings already present"
    fi
}

# Function to ensure essential desktop settings are present
ensure_desktop_input_settings() {
    local temp_file="/tmp/input_conf_$$"
    local changes_made=false
    
    # If input.conf doesn't exist, create minimal desktop config
    if [[ ! -f "$INPUT_CONF" ]]; then
        echo "📝 Creating minimal desktop input configuration..."
        cat > "$INPUT_CONF" << 'EOF'
# ================================
# HYPRLAND INPUT CONFIG
# ================================
# Essential desktop-optimized settings

input {
    # Essential touchpad settings for desktop
    touchpad {
        natural_scroll = false
    }
}

# Essential gesture settings for desktop
gestures {
    workspace_swipe = false
}
EOF
        return
    fi
    
    # Read existing config and ensure minimal desktop settings
    cp "$INPUT_CONF" "$temp_file"
    
    # Ensure natural_scroll = false for desktop
    if ! grep -q "natural_scroll.*false" "$INPUT_CONF"; then
        if grep -q "natural_scroll.*true" "$INPUT_CONF"; then
            sed -i 's/natural_scroll = true/natural_scroll = false/' "$temp_file"
            changes_made=true
        elif grep -q "touchpad {" "$INPUT_CONF"; then
            # Add natural_scroll inside existing touchpad block
            sed -i '/touchpad {/a\        natural_scroll = false' "$temp_file"
            changes_made=true
        fi
    fi
    
    # Ensure workspace_swipe = false for desktop
    if ! grep -q "workspace_swipe.*false" "$INPUT_CONF"; then
        if grep -q "workspace_swipe.*true" "$INPUT_CONF"; then
            sed -i 's/workspace_swipe = true/workspace_swipe = false/' "$temp_file"
            changes_made=true
        elif grep -q "gestures {" "$INPUT_CONF"; then
            # Add workspace_swipe inside existing gestures block
            sed -i '/gestures {/a\    workspace_swipe = false' "$temp_file"
            changes_made=true
        else
            # Add gestures block if it doesn't exist
            echo "" >> "$temp_file"
            echo "# Essential gestures for desktop" >> "$temp_file"
            echo "gestures {" >> "$temp_file"
            echo "    workspace_swipe = false" >> "$temp_file"
            echo "}" >> "$temp_file"
            changes_made=true
        fi
    fi
    
    # Apply changes if any were made
    if [[ "$changes_made" == true ]]; then
        mv "$temp_file" "$INPUT_CONF"
        echo "✅ Updated essential desktop settings in existing config"
    else
        rm -f "$temp_file"
        echo "✅ Essential desktop settings already present"
    fi
}

# Function to show configuration summary
show_config_summary() {
    local device_type="$1"
    local monitor_count="$2"
    
    echo -e "${GREEN}🎉 Hyprland configuration complete!${NC}"
    echo
    echo -e "${BLUE}📊 Configuration Summary:${NC}"
    echo -e "   Device Type: ${YELLOW}$device_type${NC}"
    echo -e "   Monitors: ${YELLOW}$monitor_count${NC}"
    echo
    
    if [[ "$device_type" == "laptop" ]]; then
        echo -e "${BLUE}📱 Essential Laptop Settings:${NC}"
        echo "   • Natural scrolling enabled"
        echo "   • Workspace swipe gestures enabled"
        echo "   • Built-in display prioritized"
        echo "   • Interface scaled to 1.25x for readability"
        echo "   • Existing config preserved"
    else
        echo -e "${BLUE}🖥️  Essential Desktop Settings:${NC}"
        echo "   • Standard scrolling (not inverted)"
        echo "   • Workspace gestures disabled"
        echo "   • Multi-monitor optimized"
        echo "   • Existing config preserved"
    fi
    
    echo
    echo -e "${GREEN}💡 Next Steps:${NC}"
    echo "   1. Reload Hyprland: Super+Shift+R"
    echo "   2. Or restart Hyprland completely"
    echo
    echo -e "${BLUE}📁 Generated/Modified Files:${NC}"
    echo "   • $(basename "$MONITORS_CONF")"
    echo "   • $(basename "$INPUT_CONF")"
    echo "   • $(basename "$ENV_CONF")"
}

# Main function
main() {
    local quiet_mode=false
    local force_overwrite=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quiet)
                quiet_mode=true
                shift
                ;;
            --force)
                force_overwrite=true
                shift
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                echo "Usage: $0 [--quiet] [--force]"
                exit 1
                ;;
        esac
    done
    
    if [[ "$quiet_mode" == false ]]; then
        echo -e "${BLUE}🚀 Hyprland Auto-Configuration${NC}"
        echo -e "${PURPLE}Detecting device and optimizing settings...${NC}"
        echo
    fi
    
    # Detect device type
    local device_type=$(detect_device_type)
    
    if [[ "$quiet_mode" == false ]]; then
        echo -e "${BLUE}🔍 Detected device: ${YELLOW}${device_type}${NC}"
        echo
    fi
    
    # Check for existing configs and confirm overwrite (unless quiet/force)
    if [[ "$force_overwrite" == false && "$quiet_mode" == false ]]; then
        local configs_exist=false
        if [[ -f "$MONITORS_CONF" || -f "$INPUT_CONF" ]]; then
            configs_exist=true
        fi
        
        if [[ "$configs_exist" == true ]]; then
            echo -e "${YELLOW}⚠️  Existing Hyprland configurations found${NC}"
            read -p "Overwrite with $device_type-optimized settings? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Configuration unchanged${NC}"
                exit 0
            fi
            echo
        fi
    fi
    
    # Create config directory if it doesn't exist
    mkdir -p "$HYPR_CONFIG_DIR"
    
    # Backup existing configs
    backup_config "$MONITORS_CONF" "monitors.conf"
    backup_config "$INPUT_CONF" "input.conf"
    backup_config "$ENV_CONF" "env.conf"
    
    # Configure monitors
    if [[ "$quiet_mode" == false ]]; then
        echo -e "${BLUE}🖥️  Configuring monitors...${NC}"
    fi
    
    local monitor_info_array=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && monitor_info_array+=("$line")
    done < <(get_monitor_info)
    
    generate_monitor_config "${monitor_info_array[@]}"
    
    # Configure input based on device type
    if [[ "$quiet_mode" == false ]]; then
        echo -e "${BLUE}🖱️  Optimizing input settings...${NC}"
    fi
    
    if [[ "$device_type" == "laptop" ]]; then
        ensure_laptop_input_settings
        if [[ "$quiet_mode" == false ]]; then
            echo -e "${BLUE}🔍 Setting up interface scaling for better readability...${NC}"
        fi
        ensure_laptop_scaling_env
    else
        ensure_desktop_input_settings
        if [[ "$quiet_mode" == false ]]; then
            echo -e "${BLUE}🔍 Setting up standard interface scaling...${NC}"
        fi
        ensure_desktop_scaling_env
    fi
    
    # Show summary
    if [[ "$quiet_mode" == false ]]; then
        echo
        show_config_summary "$device_type" "${#monitor_info_array[@]}"
    fi
}

# Run main function with all arguments
main "$@" 