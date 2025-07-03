#!/bin/bash

# setup-hyprland.sh - Complete Hyprland setup and configuration
# Handles monitors, workspaces, input settings, and device-specific optimization

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

HYPR_CONFIG_DIR="$DOTFILES_DIR/stow/hypr/.config/hypr"
USER_HYPR_DIR="$HOME/.config/hypr"

show_help() {
    log_section "Hyprland Setup Manager"
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo -e "  ${GREEN}setup${NC}       Complete Hyprland setup (default)"
    echo -e "  ${GREEN}monitors${NC}    Auto-configure monitors only"
    echo -e "  ${GREEN}workspaces${NC}  Setup workspaces configuration"
    echo -e "  ${GREEN}input${NC}       Configure input settings"
    echo -e "  ${GREEN}status${NC}      Check Hyprland status"
    echo
    echo "Options:"
    echo "  --force       Skip confirmations"
    echo "  --quiet       Minimal output"
}

# Parse arguments
COMMAND="setup"
FORCE=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        setup|monitors|workspaces|input|status)
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
    local monitors=()
    local monitor_info=()
    
    if has_command hyprctl && hyprctl monitors &>/dev/null; then
        # Parse hyprctl for detailed monitor info
        local current_monitor=""
        local current_resolution=""
        local current_refresh=""
        
        while IFS= read -r line; do
            if [[ $line =~ ^Monitor\ ([^[:space:]]+)\ \(ID ]]; then
                if [[ -n "$current_monitor" ]]; then
                    monitors+=("$current_monitor")
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
            monitors+=("$current_monitor")
            monitor_info+=("$current_monitor:$current_resolution@$current_refresh")
        fi
    else
        # Fallback detection
        while IFS= read -r line; do
            if [[ $line =~ ^([^[:space:]]+)\ connected ]]; then
                monitors+=("${BASH_REMATCH[1]}")
                monitor_info+=("${BASH_REMATCH[1]}:preferred")
            fi
        done <<< "$(xrandr 2>/dev/null)"
    fi
    
    # Return monitor info array
    printf '%s\n' "${monitor_info[@]}"
}

# Generate enhanced monitor configuration with device-specific scaling
generate_monitor_config() {
    local monitor_info=("$@")
    local device_type=$(detect_device_type)
    local config=""
    local x_offset=0
    
    config+="# Auto-generated monitor configuration\n"
    config+="# Generated on $(date)\n"
    config+="# Device type: $device_type\n"
    config+="# Detected monitors: $(echo "${monitor_info[@]}" | cut -d':' -f1 | tr '\n' ' ')\n\n"
    
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

# Generate device-specific input configuration
generate_input_config() {
    local device_type="$1"
    local input_conf="$HYPR_CONFIG_DIR/input.conf"
    local config=""
    
    config+="# Auto-generated input configuration\n"
    config+="# Generated on $(date)\n"
    config+="# Device type: $device_type\n\n"
    
    if [[ "$device_type" == "laptop" ]]; then
        config+="# Laptop-optimized input settings\n"
        config+="input {\n"
        config+="    touchpad {\n"
        config+="        natural_scroll = true\n"
        config+="        disable_while_typing = true\n"
        config+="        tap-to-click = true\n"
        config+="        scroll_factor = 1.0\n"
        config+="    }\n"
        config+="}\n\n"
        config+="# Laptop gesture settings\n"
        config+="gestures {\n"
        config+="    workspace_swipe = true\n"
        config+="    workspace_swipe_fingers = 3\n"
        config+="    workspace_swipe_distance = 300\n"
        config+="    workspace_swipe_create_new = true\n"
        config+="}\n"
    else
        config+="# Desktop-optimized input settings\n"
        config+="input {\n"
        config+="    touchpad {\n"
        config+="        natural_scroll = false\n"
        config+="    }\n"
        config+="}\n\n"
        config+="# Desktop gesture settings\n"
        config+="gestures {\n"
        config+="    workspace_swipe = false\n"
        config+="}\n"
    fi
    
    echo -e "$config"
}

# Configure input settings
cmd_input() {
    local device_type=$(detect_device_type)
    
    [[ "$QUIET" != true ]] && log_step "Configuring input for $device_type..."
    
    local input_conf="$HYPR_CONFIG_DIR/input.conf"
    ensure_dir "$(dirname "$input_conf")"
    
    # Backup existing config
    backup_file "$input_conf"
    
    # Generate and write new config
    local config=$(generate_input_config "$device_type")
    echo -e "$config" > "$input_conf"
    
    log_success "Input configuration written to input.conf"
}

# Configure monitors
cmd_monitors() {
    [[ "$QUIET" != true ]] && log_step "Configuring monitors..."
    
    local monitor_info=($(detect_monitors_enhanced))
    
    if [[ ${#monitor_info[@]} -eq 0 ]]; then
        log_error "No monitors detected"
        return 1
    fi
    
    [[ "$QUIET" != true ]] && log_info "Detected monitors: $(echo "${monitor_info[@]}" | cut -d':' -f1 | tr '\n' ' ')"
    
    # Generate configuration
    local config=$(generate_monitor_config "${monitor_info[@]}")
    
    # Write to monitors.conf
    local monitors_conf="$HYPR_CONFIG_DIR/monitors.conf"
    ensure_dir "$(dirname "$monitors_conf")"
    
    # Backup existing config
    backup_file "$monitors_conf"
    
    # Write new config
    echo -e "$config" > "$monitors_conf"
    log_success "Monitor configuration written to monitors.conf"
    
    # Reload if Hyprland is running
    if has_command hyprctl && hyprctl version &>/dev/null; then
        hyprctl reload 2>/dev/null && log_success "Hyprland reloaded" || log_warning "Failed to reload Hyprland"
    fi
}

# Generate workspace configuration
generate_workspace_config() {
    local monitor_info=("$@")
    local config=""
    local monitors=($(echo "${monitor_info[@]}" | cut -d':' -f1))
    
    config+="# Auto-generated workspace configuration\n"
    config+="# Generated on $(date)\n\n"
    
    if [[ ${#monitors[@]} -eq 1 ]]; then
        # Single monitor setup
        config+="# Single monitor - all workspaces\n"
        for i in {1..10}; do
            config+="workspace = $i,monitor:${monitors[0]}\n"
        done
    else
        # Multi-monitor setup - smart distribution
        config+="# Multi-monitor workspace distribution\n"
        local monitor_count=${#monitors[@]}
        local ws_per_monitor=$((10 / monitor_count))
        
        for ((i=0; i<monitor_count; i++)); do
            local start_ws=$((i * ws_per_monitor + 1))
            local end_ws=$(((i + 1) * ws_per_monitor))
            if [[ $i -eq $((monitor_count - 1)) ]]; then
                end_ws=10  # Last monitor gets remaining workspaces
            fi
            
            config+="\n# Monitor ${monitors[i]} - workspaces $start_ws-$end_ws\n"
            for ((ws=start_ws; ws<=end_ws; ws++)); do
                config+="workspace = $ws,monitor:${monitors[i]}\n"
            done
        done
    fi
    
    echo -e "$config"
}

# Configure workspaces
cmd_workspaces() {
    [[ "$QUIET" != true ]] && log_step "Configuring workspaces..."
    
    local monitor_info=($(detect_monitors_enhanced))
    
    if [[ ${#monitor_info[@]} -eq 0 ]]; then
        log_error "No monitors detected"
        return 1
    fi
    
    # Generate workspace configuration
    local config=$(generate_workspace_config "${monitor_info[@]}")
    
    # Write to workspaces.conf
    local workspaces_conf="$HYPR_CONFIG_DIR/workspaces.conf"
    ensure_dir "$(dirname "$workspaces_conf")"
    
    # Backup existing config
    backup_file "$workspaces_conf"
    
    # Write new config
    echo -e "$config" > "$workspaces_conf"
    log_success "Workspace configuration written to workspaces.conf"
}

# Show Hyprland status
cmd_status() {
    log_section "Hyprland Status"
    
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
        echo -e "${BLUE}📺 Monitors:${NC}"
        hyprctl monitors 2>/dev/null | grep -E "^Monitor|^\s+[0-9]+x[0-9]+" | sed 's/^/  /'
        
        # Show workspaces
        echo
        echo -e "${BLUE}🗂️  Workspaces:${NC}"
        hyprctl workspaces 2>/dev/null | grep -E "^workspace ID" | sed 's/^/  /'
        
    else
        log_warning "Hyprland not running"
    fi
    
    # Check config files
    echo
    echo -e "${BLUE}📁 Configuration Files:${NC}"
    
    local config_files=("hyprland.conf" "monitors.conf" "workspaces.conf" "input.conf")
    for file in "${config_files[@]}"; do
        local file_path="$HYPR_CONFIG_DIR/$file"
        if [[ -f "$file_path" ]]; then
            log_success "$file exists"
        else
            log_warning "$file missing"
        fi
    done
}

# Complete Hyprland setup
cmd_setup() {
    if ! check_hyprland; then
        return 1
    fi
    
    local device_type=$(detect_device_type)
    
    log_section "Complete Hyprland Setup"
    [[ "$QUIET" != true ]] && log_info "Detected device: $device_type"
    echo
    
    # Step 1: Configure monitors with device-specific scaling
    log_step "Step 1: Configuring monitors with $device_type optimization..."
    cmd_monitors
    echo
    
    # Step 2: Configure input settings
    log_step "Step 2: Configuring input settings for $device_type..."
    cmd_input
    echo
    
    # Step 3: Configure workspaces  
    log_step "Step 3: Configuring workspaces..."
    cmd_workspaces
    echo
    
    # Step 4: Ensure main config includes our files
    log_step "Step 4: Updating main configuration..."
    local main_config="$HYPR_CONFIG_DIR/hyprland.conf"
    
    if [[ -f "$main_config" ]]; then
        # Check if our includes are already there
        local needs_monitors=true
        local needs_workspaces=true
        local needs_input=true
        
        if grep -q "source.*monitors\.conf" "$main_config"; then
            needs_monitors=false
        fi
        
        if grep -q "source.*workspaces\.conf" "$main_config"; then
            needs_workspaces=false
        fi
        
        if grep -q "source.*input\.conf" "$main_config"; then
            needs_input=false
        fi
        
        # Add includes if needed
        if $needs_monitors || $needs_workspaces || $needs_input; then
            backup_file "$main_config"
            
            if $needs_monitors; then
                echo -e "\n# Auto-generated monitor configuration\nsource = ~/.config/hypr/monitors.conf" >> "$main_config"
                log_info "Added monitors.conf include"
            fi
            
            if $needs_input; then
                echo -e "\n# Auto-generated input configuration\nsource = ~/.config/hypr/input.conf" >> "$main_config"
                log_info "Added input.conf include"
            fi
            
            if $needs_workspaces; then
                echo -e "\n# Auto-generated workspace configuration\nsource = ~/.config/hypr/workspaces.conf" >> "$main_config"
                log_info "Added workspaces.conf include"
            fi
        fi
    else
        log_warning "Main Hyprland config not found - install hypr configs first"
    fi
    
    log_success "Hyprland setup complete!"
    
    if [[ "$device_type" == "laptop" ]]; then
        echo
        echo -e "${YELLOW}💡 Laptop optimizations applied:${NC}"
        echo "  • Natural scrolling enabled"
        echo "  • Touchpad gestures enabled"
        echo "  • Interface scaled to 1.25x"
        echo "  • Tap-to-click enabled"
    else
        echo
        echo -e "${YELLOW}💡 Desktop optimizations applied:${NC}"
        echo "  • Standard scrolling (not natural)"
        echo "  • Gestures disabled"
        echo "  • No interface scaling"
    fi
    
    if has_command hyprctl && hyprctl version &>/dev/null; then
        echo
        log_info "Reloading Hyprland configuration..."
        hyprctl reload 2>/dev/null && log_success "Configuration reloaded" || log_warning "Failed to reload"
    else
        echo
        log_info "Start Hyprland to apply changes"
    fi
}

# Execute command
case "$COMMAND" in
    setup)
        cmd_setup
        ;;
    monitors)
        cmd_monitors
        ;;
    workspaces)
        cmd_workspaces
        ;;
    input)
        cmd_input
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