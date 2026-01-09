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

    # Request sudo access once upfront (hyprpm needs it for loading/unloading plugins)
    # Skip prompt if running in full install (sudo already obtained)
    if [[ "${FULL_INSTALL:-false}" != "true" ]]; then
        log_info "Requesting elevated privileges for plugin operations..."
        sudo -v || {
            log_error "Sudo access required for plugin management"
            return 1
        }
        echo
    fi

    # Keep sudo alive in background during plugin operations
    (while true; do sudo -v; sleep 50; done) 2>/dev/null &
    local sudo_keepalive_pid=$!

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

    # Stop the sudo keepalive background process
    kill "$sudo_keepalive_pid" 2>/dev/null || true

    # Enable each configured plugin
    local enabled_count=0
    local failed_count=0

    for plugin_name in "${plugin_names[@]}"; do
        log_info "Enabling plugin: $plugin_name"
        
        if is_plugin_enabled "$plugin_name"; then
            log_success "Already enabled: $plugin_name"
            ((enabled_count++))
        else
            if hyprpm enable "$plugin_name" 2>/dev/null; then
                log_success "Enabled: $plugin_name"
                ((enabled_count++))
            else
                log_error "Failed to enable: $plugin_name"
                log_info "Make sure '$plugin_name' is a valid plugin name"
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
