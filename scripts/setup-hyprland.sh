#!/bin/bash

# setup-hyprland.sh - Complete Hyprland setup and configuration
# Handles monitors, workspaces, and Hyprland-specific settings

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
        setup|monitors|workspaces|status)
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

# Detect connected monitors
detect_monitors() {
    local monitors=()
    
    if has_command hyprctl && hyprctl monitors &>/dev/null; then
        # Parse hyprctl output
        while IFS= read -r line; do
            if [[ $line =~ ^Monitor\ ([^[:space:]]+)\ \(ID ]]; then
                monitors+=("${BASH_REMATCH[1]}")
            fi
        done <<< "$(hyprctl monitors 2>/dev/null)"
    else
        # Fallback detection
        if has_command xrandr; then
            while IFS= read -r line; do
                if [[ $line =~ ^([^[:space:]]+)\ connected ]]; then
                    monitors+=("${BASH_REMATCH[1]}")
                fi
            done <<< "$(xrandr 2>/dev/null)"
        fi
    fi
    
    printf '%s\n' "${monitors[@]}"
}

# Generate monitor configuration
generate_monitor_config() {
    local monitors=("$@")
    local config=""
    local x_offset=0
    
    config+="# Auto-generated monitor configuration\n"
    config+="# Generated on $(date)\n"
    config+="# Detected monitors: ${monitors[*]}\n\n"
    
    # Handle laptop (built-in) displays first
    local builtin_monitors=()
    local external_monitors=()
    
    for monitor in "${monitors[@]}"; do
        if [[ "$monitor" =~ ^(eDP|LVDS|DSI) ]]; then
            builtin_monitors+=("$monitor")
        else
            external_monitors+=("$monitor")
        fi
    done
    
    # Configure built-in monitors
    for monitor in "${builtin_monitors[@]}"; do
        config+="monitor = $monitor,preferred,${x_offset}x0,1\n"
        x_offset=$((x_offset + 1920)) # Assume 1920 width
    done
    
    # Configure external monitors
    for monitor in "${external_monitors[@]}"; do
        config+="monitor = $monitor,preferred,${x_offset}x0,1\n"
        x_offset=$((x_offset + 1920))
    done
    
    # Fallback for unknown monitors
    config+="\n# Fallback for unrecognized monitors\n"
    config+="monitor = ,preferred,auto,1\n"
    
    echo -e "$config"
}

# Generate workspace configuration
generate_workspace_config() {
    local monitors=("$@")
    local config=""
    
    config+="# Auto-generated workspace configuration\n"
    config+="# Generated on $(date)\n\n"
    
    if [[ ${#monitors[@]} -eq 1 ]]; then
        # Single monitor setup
        config+="# Single monitor - all workspaces\n"
        for i in {1..10}; do
            config+="workspace = $i,monitor:${monitors[0]}\n"
        done
    else
        # Multi-monitor setup
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

# Configure monitors
cmd_monitors() {
    [[ "$QUIET" != true ]] && log_step "Configuring monitors..."
    
    local monitors=($(detect_monitors))
    
    if [[ ${#monitors[@]} -eq 0 ]]; then
        log_error "No monitors detected"
        return 1
    fi
    
    [[ "$QUIET" != true ]] && log_info "Detected monitors: ${monitors[*]}"
    
    # Generate configuration
    local config=$(generate_monitor_config "${monitors[@]}")
    
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

# Configure workspaces
cmd_workspaces() {
    [[ "$QUIET" != true ]] && log_step "Configuring workspaces..."
    
    local monitors=($(detect_monitors))
    
    if [[ ${#monitors[@]} -eq 0 ]]; then
        log_error "No monitors detected"
        return 1
    fi
    
    # Generate workspace configuration
    local config=$(generate_workspace_config "${monitors[@]}")
    
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
    
    local config_files=("hyprland.conf" "monitors.conf" "workspaces.conf")
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
    
    log_section "Complete Hyprland Setup"
    
    # Step 1: Configure monitors
    log_step "Step 1: Configuring monitors..."
    cmd_monitors
    echo
    
    # Step 2: Configure workspaces  
    log_step "Step 2: Configuring workspaces..."
    cmd_workspaces
    echo
    
    # Step 3: Ensure main config includes our files
    log_step "Step 3: Updating main configuration..."
    local main_config="$HYPR_CONFIG_DIR/hyprland.conf"
    
    if [[ -f "$main_config" ]]; then
        # Check if our includes are already there
        local needs_monitors=true
        local needs_workspaces=true
        
        if grep -q "source.*monitors\.conf" "$main_config"; then
            needs_monitors=false
        fi
        
        if grep -q "source.*workspaces\.conf" "$main_config"; then
            needs_workspaces=false
        fi
        
        # Add includes if needed
        if $needs_monitors || $needs_workspaces; then
            backup_file "$main_config"
            
            if $needs_monitors; then
                echo -e "\n# Auto-generated monitor configuration\nsource = ~/.config/hypr/monitors.conf" >> "$main_config"
                log_info "Added monitors.conf include"
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
    status)
        cmd_status
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac 