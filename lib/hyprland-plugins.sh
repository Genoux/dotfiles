#!/bin/bash
# Hyprland plugin management
#
# Configuration format in packages/hyprland-plugins.package:
#   plugin_name = repository_url
#
# Example:
#   Hyprspace = https://github.com/KZDKM/Hyprspace
#   split-monitor-workspaces = https://github.com/Duckonaut/split-monitor-workspaces

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Plugin configuration file
HYPRLAND_PLUGINS_FILE="$DOTFILES_DIR/packages/hyprland-plugins.package"

# Load plugins from configuration file
# Format: plugin_name = repository_url
load_plugin_config() {
    declare -gA HYPRLAND_PLUGINS

    if [[ ! -f "$HYPRLAND_PLUGINS_FILE" ]]; then
        log_warning "Plugin configuration file not found: $HYPRLAND_PLUGINS_FILE"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*#.*$ ]] && continue

        # Parse line: plugin_name = repository_url
        if [[ "$line" =~ ^[[:space:]]*([^=]+)[[:space:]]*=[[:space:]]*(.+)[[:space:]]*$ ]]; then
            local plugin_name="${BASH_REMATCH[1]}"
            local plugin_url="${BASH_REMATCH[2]}"

            # Trim whitespace
            plugin_name="${plugin_name## }"
            plugin_name="${plugin_name%% }"
            plugin_url="${plugin_url## }"
            plugin_url="${plugin_url%% }"

            # Validate both fields are present
            if [[ -z "$plugin_name" ]] || [[ -z "$plugin_url" ]]; then
                log_warning "Invalid plugin entry (missing name or URL): $line"
                continue
            fi

            HYPRLAND_PLUGINS["$plugin_name"]="$plugin_url"
        else
            log_warning "Invalid plugin entry format (expected: name = url): $line"
        fi
    done < "$HYPRLAND_PLUGINS_FILE"
}

# Ensure hyprpm is available
ensure_hyprpm() {
    if ! command -v hyprpm &>/dev/null; then
        fatal_error "hyprpm not found. Please ensure Hyprland is installed."
    fi
}

# Get list of enabled plugins
get_enabled_plugins() {
    hyprpm list 2>/dev/null | grep "Plugin" | awk '{print $2}' || true
}

# Get list of all installed plugins (enabled or disabled)
get_all_installed_plugins() {
    # Get all plugin names from hyprpm list
    # Format: "│ Plugin PluginName" or "→ Repository PluginName:"
    hyprpm list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E "(^│ Plugin|^→ Repository)" | sed 's/^│ Plugin //; s/^→ Repository //; s/:$//' | sort -u || true
}

# Check if plugin is enabled
is_plugin_enabled() {
    local plugin_name="$1"
    # Strip ANSI codes and check if plugin is enabled
    hyprpm list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -A1 "Plugin $plugin_name" | grep -q "enabled.*true"
}

# Check if plugin is installed (enabled or disabled)
is_plugin_installed() {
    local plugin_name="$1"
    # Check if plugin appears in the list (either as "│ Plugin PluginName" or "→ Repository PluginName:")
    hyprpm list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -qE "(│ Plugin $plugin_name|→ Repository $plugin_name:)"
}

# Remove a plugin
remove_plugin() {
    local plugin_name="$1"
    
    # Disable first if enabled
    if is_plugin_enabled "$plugin_name"; then
        hyprpm disable "$plugin_name" 2>/dev/null || true
    fi
    
    # Remove plugin
    if hyprpm remove "$plugin_name" 2>/dev/null; then
        log_success "Removed: $plugin_name"
        return 0
    else
        log_warning "Failed to remove: $plugin_name"
        return 1
    fi
}

# Install and enable a plugin
install_plugin() {
    local plugin_name="$1"
    local plugin_url="$2"

    log_info "Installing plugin: $plugin_name"
    echo

    # Check if plugin is already installed and enabled
    if is_plugin_enabled "$plugin_name"; then
        log_success "Plugin already installed and enabled: $plugin_name"
        return 0
    fi

    # Add plugin if not already added
    if ! hyprpm list 2>/dev/null | grep -q "$plugin_url"; then
        log_info "Adding plugin from $plugin_url..."
        if ! hyprpm add "$plugin_url"; then
            log_error "Failed to add plugin: $plugin_name"
            log_info "Please run manually: hyprpm add $plugin_url"
            return 1
        fi
    else
        log_info "Plugin repository already added"
    fi

    # Enable plugin
    log_info "Enabling plugin: $plugin_name..."
    if ! hyprpm enable "$plugin_name"; then
        log_error "Failed to enable plugin: $plugin_name"
        return 1
    fi

    log_success "Plugin installed and enabled: $plugin_name"
    echo
}

# Setup all configured plugins
setup_hyprland_plugins() {
    log_section "Setting up Hyprland Plugins"

    ensure_hyprpm

    # Load plugin configuration
    load_plugin_config

    # Ensure build dependencies are installed first (before any plugin operations)
    log_info "Checking build dependencies..."
    local deps=(cmake meson cpio git gcc)
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Installing missing dependencies: ${missing[*]}"
        sudo pacman -S --needed --noconfirm "${missing[@]}" || {
            log_error "Failed to install dependencies"
            return 1
        }
        echo
    else
        log_success "All dependencies installed"
    fi
    echo

    # Cache sudo credentials upfront to avoid multiple password prompts
    # hyprpm operations may require sudo for loading/unloading plugins
    sudo -v 2>/dev/null || true

    # Get list of currently installed plugins and remove orphaned ones
    local installed_plugins=()
    while IFS= read -r plugin; do
        [[ -n "$plugin" ]] && installed_plugins+=("$plugin")
    done < <(get_all_installed_plugins)

    # Remove plugins that are installed but not in config
    if [[ ${#installed_plugins[@]} -gt 0 ]]; then
        local removed_count=0
        
        for installed_plugin in "${installed_plugins[@]}"; do
            # Check if plugin is in config
            if [[ -z "${HYPRLAND_PLUGINS[$installed_plugin]:-}" ]]; then
                if remove_plugin "$installed_plugin"; then
                    ((removed_count++))
                fi
            fi
        done
        
        if [[ $removed_count -gt 0 ]]; then
            log_success "Removed $removed_count orphaned plugin(s)"
            echo
        fi
    fi

    # Install/update each plugin from config
    if [[ ${#HYPRLAND_PLUGINS[@]} -eq 0 ]]; then
        log_info "No plugins configured in $HYPRLAND_PLUGINS_FILE"
    else
        local installed_count=0
        local updated_count=0
        local failed_count=0

        for plugin_name in "${!HYPRLAND_PLUGINS[@]}"; do
            local plugin_url="${HYPRLAND_PLUGINS[$plugin_name]}"

            if is_plugin_enabled "$plugin_name"; then
                log_info "Plugin already enabled: $plugin_name (will update)"
                ((installed_count++))
            elif is_plugin_installed "$plugin_name"; then
                log_info "Plugin installed but disabled: $plugin_name (enabling and updating)"
                if hyprpm enable "$plugin_name" 2>/dev/null; then
                    ((installed_count++))
                else
                    log_warning "Failed to enable plugin: $plugin_name"
                    ((failed_count++))
                fi
            else
                if install_plugin "$plugin_name" "$plugin_url"; then
                    ((installed_count++))
                else
                    ((failed_count++))
                fi
            fi
        done

        echo
        if [[ $failed_count -eq 0 ]]; then
            log_success "All plugins configured successfully ($installed_count/${#HYPRLAND_PLUGINS[@]})"
        else
            log_warning "$failed_count plugin(s) failed to install"
        fi

        # Update all plugins
        log_info "Updating plugins..."
        hyprpm update
    fi

}

# Reload plugins
reload_hyprland_plugins() {
    log_section "Reloading Hyprland Plugins"

    ensure_hyprpm

    log_info "Reloading all enabled plugins..."
    if hyprpm reload -n; then
        log_success "Plugins reloaded successfully"
    else
        log_error "Failed to reload plugins"
        return 1
    fi
}

# Show plugin status
show_hyprland_plugins_status() {
    log_section "Hyprland Plugins Status"

    ensure_hyprpm

    log_info "Enabled plugins:"
    local enabled=$(get_enabled_plugins)
    if [[ -n "$enabled" ]]; then
        while IFS= read -r plugin; do
            echo "  ✓ $plugin"
        done <<< "$enabled"
    else
        echo "  No plugins enabled"
    fi

    echo
    log_info "Configured plugins:"
    for plugin_name in "${!HYPRLAND_PLUGINS[@]}"; do
        if is_plugin_enabled "$plugin_name"; then
            echo "  ✓ $plugin_name (enabled)"
        else
            echo "  ✗ $plugin_name (not enabled)"
        fi
    done
}
