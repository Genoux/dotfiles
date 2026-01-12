#!/bin/bash
# Hyprland plugin management
#
# Simple plugin system: lists plugins from hyprland-plugins repo
# Configuration format in packages/hyprland-plugins.package:
#   Just list plugin names, one per line
#
# Example:
#   hyprexpo
#   hyprbars
#   hyprtrails

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Official Hyprland plugins repository
HYPRLAND_PLUGINS_REPO="https://github.com/hyprwm/hyprland-plugins"

# Plugin configuration file
HYPRLAND_PLUGINS_FILE="$DOTFILES_DIR/packages/hyprland-plugins.package"

# Load plugin names from configuration file
load_plugin_names() {
    local -a plugins=()

    if [[ ! -f "$HYPRLAND_PLUGINS_FILE" ]]; then
        return 0
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*#.*$ ]] && continue

        # Trim whitespace
        line="${line## }"
        line="${line%% }"
        
        # Add non-empty plugin names
        [[ -n "$line" ]] && plugins+=("$line")
    done < "$HYPRLAND_PLUGINS_FILE"
    
    printf '%s\n' "${plugins[@]}"
}

# Ensure hyprpm is available
ensure_hyprpm() {
    if ! command -v hyprpm &>/dev/null; then
        fatal_error "hyprpm not found. Please ensure Hyprland is installed."
    fi
}

# Check if repository is already added
is_repo_added() {
    local repo_url="$1"
    hyprpm list 2>/dev/null | grep -q "$repo_url"
}

# Check if plugin is enabled
is_plugin_enabled() {
    local plugin_name="$1"
    hyprpm list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -A1 "Plugin $plugin_name" | grep -q "enabled.*true"
}

# Setup all configured plugins
setup_hyprland_plugins() {
    log_section "Setting up Hyprland Plugins"

    ensure_hyprpm

    # Load plugin names from config
    local -a plugin_names=()
    while IFS= read -r name; do
        plugin_names+=("$name")
    done < <(load_plugin_names)

    if [[ ${#plugin_names[@]} -eq 0 ]]; then
        log_info "No plugins configured in $HYPRLAND_PLUGINS_FILE"
        log_info "Add plugin names (one per line) to enable them"
        echo
        log_info "Available plugins: hyprexpo, hyprbars, hyprtrails, hyprwinwrap, etc."
        return 0
    fi

    log_info "Configured plugins: ${plugin_names[*]}"
    echo

    # Ensure build dependencies are installed
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

    # hyprpm needs sudo for plugin operations
    # Note: With NOPASSWD configured in sudoers, no password prompt will appear

    # Ensure repository is added (try to add, ignore if already exists)
    log_info "Ensuring official Hyprland plugins repository..."
    hyprpm add "$HYPRLAND_PLUGINS_REPO" < <(echo "y") 2>/dev/null || true
    echo

    # Update plugins (this will work whether repo was just added or already existed)
    log_info "Updating plugins from repository..."
    if ! hyprpm update < <(echo "y") 2>&1; then
        log_warning "Update may have failed, but continuing..."
    fi
    echo

    # Enable each configured plugin
    local enabled_count=0
    local failed_count=0

    for plugin_name in "${plugin_names[@]}"; do
        log_info "Enabling plugin: $plugin_name"
        
        if is_plugin_enabled "$plugin_name"; then
            log_success "Already enabled: $plugin_name"
            ((enabled_count++))
        else
            # Capture error output for debugging
            local enable_output
            if enable_output=$(hyprpm enable "$plugin_name" 2>&1); then
                log_success "Enabled: $plugin_name"
                ((enabled_count++))
            else
                log_error "Failed to enable: $plugin_name"
                if [[ -n "$enable_output" ]]; then
                    log_info "Error: $enable_output"
                fi
                log_info "Make sure '$plugin_name' is a valid plugin name and hyprpm is working correctly"
                ((failed_count++))
            fi
        fi
        echo
    done

    # Summary
    if [[ $failed_count -eq 0 ]]; then
        log_success "All plugins enabled successfully ($enabled_count/${#plugin_names[@]})"
    else
        log_warning "$failed_count plugin(s) failed to enable"
    fi
    
    # Rebuild plugins after enabling to ensure they match current Hyprland version
    # This prevents version mismatch errors when reloading
    if command -v hyprctl &>/dev/null && hyprctl version &>/dev/null 2>&1; then
        echo
        log_info "Rebuilding plugins for current Hyprland version..."
        if hyprpm update < <(echo "y") 2>&1; then
            log_success "Plugins rebuilt successfully"
        else
            log_warning "Plugin rebuild may have failed, but continuing..."
        fi
    fi
    
    # Reload plugins if Hyprland is running
    if command -v hyprctl &>/dev/null && hyprctl version &>/dev/null 2>&1; then
        echo
        log_info "Reloading plugins in running Hyprland instance..."
        
        # Capture reload output to check for version mismatch
        local reload_output
        reload_output=$(hyprpm reload -n 2>&1) || true
        
        if echo "$reload_output" | grep -qi "version mismatch\|mismatch\|rebuild"; then
            log_warning "Version mismatch detected - rebuilding plugins..."
            # Rebuild plugins to match current Hyprland version
            if hyprpm update < <(echo "y") 2>&1; then
                log_success "Plugins rebuilt successfully"
                # Try reloading again after rebuild
                if hyprpm reload -n 2>/dev/null; then
                    log_success "Plugins reloaded after rebuild"
                else
                    log_warning "Plugins rebuilt but reload failed. Restart Hyprland to load plugins"
                fi
            else
                log_error "Failed to rebuild plugins"
                log_info "You may need to restart Hyprland for plugins to work"
            fi
        elif echo "$reload_output" | grep -qi "failed to write plugin state"; then
            log_warning "Plugin state write failed - this may be a permissions issue"
            log_info "Plugins may still work. Try restarting Hyprland if issues persist"
        elif [[ -z "$reload_output" ]] || echo "$reload_output" | grep -qi "reloaded\|success\|loaded.*hyprexpo"; then
            log_success "Plugins reloaded"
        else
            log_warning "Reload may have failed: $reload_output"
            log_info "Trying to rebuild plugins..."
            if hyprpm update < <(echo "y") 2>&1; then
                log_success "Plugins rebuilt - restart Hyprland to load them"
            else
                log_warning "Failed to rebuild. You may need to restart Hyprland"
            fi
        fi
        
        # Verify plugins are actually loaded
        echo
        log_info "Verifying plugin status..."
        local plugins_loaded=$(hyprctl plugins list 2>&1)
        
        for plugin_name in "${plugin_names[@]}"; do
            if is_plugin_enabled "$plugin_name"; then
                # Check if plugin is actually loaded in Hyprland
                if echo "$plugins_loaded" | grep -qi "$plugin_name\|no plugins loaded"; then
                    if echo "$plugins_loaded" | grep -qi "no plugins loaded"; then
                        log_warning "$plugin_name is enabled but NOT loaded (version mismatch?)"
                        log_info "  Run 'hyprpm reload' or restart Hyprland"
                    elif echo "$plugins_loaded" | grep -qi "$plugin_name"; then
                        log_success "$plugin_name is enabled and loaded"
                    else
                        log_warning "$plugin_name is enabled but may not be loaded"
                    fi
                else
                    log_success "$plugin_name is enabled"
                fi
            else
                log_warning "$plugin_name is not enabled - check 'hyprpm list' for details"
            fi
        done
    else
        echo
        log_info "Hyprland not running. Plugins will be loaded when Hyprland starts"
        log_info "After starting Hyprland, run: hyprpm reload"
    fi
}

# Reload plugins
reload_hyprland_plugins() {
    log_section "Reloading Hyprland Plugins"

    ensure_hyprpm

    log_info "Reloading all enabled plugins..."
    
    # Capture reload output to check for version mismatch
    local reload_output
    reload_output=$(hyprpm reload -n 2>&1) || true
    
    if echo "$reload_output" | grep -qi "version mismatch\|mismatch\|rebuild"; then
        log_warning "Version mismatch detected - rebuilding plugins..."
        # Rebuild plugins to match current Hyprland version
        if hyprpm update < <(echo "y") 2>&1; then
            log_success "Plugins rebuilt successfully"
            # Try reloading again after rebuild
            if hyprpm reload -n 2>/dev/null; then
                log_success "Plugins reloaded after rebuild"
            else
                log_warning "Plugins rebuilt but reload failed. Restart Hyprland to load plugins"
                return 1
            fi
        else
            log_error "Failed to rebuild plugins"
            return 1
        fi
    elif [[ -z "$reload_output" ]] || echo "$reload_output" | grep -q "reloaded\|success"; then
        log_success "Plugins reloaded successfully"
    else
        log_error "Failed to reload plugins: $reload_output"
        log_info "Trying to rebuild plugins..."
        if hyprpm update < <(echo "y") 2>&1; then
            log_success "Plugins rebuilt - restart Hyprland to load them"
        else
            log_error "Failed to rebuild plugins"
            return 1
        fi
    fi
}

# Show plugin status
show_hyprland_plugins_status() {
    log_section "Hyprland Plugins Status"

    ensure_hyprpm

    # Show configured plugins
    log_info "Configured plugins:"
    local -a plugin_names=()
    while IFS= read -r name; do
        plugin_names+=("$name")
    done < <(load_plugin_names)

    if [[ ${#plugin_names[@]} -eq 0 ]]; then
        echo "  No plugins configured"
    else
        for plugin_name in "${plugin_names[@]}"; do
            if is_plugin_enabled "$plugin_name"; then
                echo "  ✓ $plugin_name (enabled)"
            else
                echo "  ✗ $plugin_name (not enabled)"
            fi
        done
    fi

    echo
    log_info "All plugins from hyprpm:"
    hyprpm list 2>/dev/null | head -30 || echo "  No plugins installed"
}
