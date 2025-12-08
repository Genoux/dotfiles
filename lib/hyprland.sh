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
    
    if [[ ${#monitors[@]} -eq 0 ]]; then
        graceful_error "No monitors detected" "Make sure Hyprland is running"
        return 1
    fi
    
    log_info "Detected monitors:"
    for info in "${monitors[@]}"; do
        local monitor_name=$(echo "$info" | cut -d':' -f1)
        local mode_info=$(echo "$info" | cut -d':' -f2)
        echo "  • $monitor_name: $mode_info"
    done
    
    echo

    # Ensure directory exists
    ensure_directory "$(dirname "$MONITORS_CONF")"

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
    log_section "Hyprland Status"

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

# Setup Hyprland with plugins and monitors
hyprland_setup_all() {
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

