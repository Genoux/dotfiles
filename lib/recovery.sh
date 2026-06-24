#!/bin/bash
# Recovery mode and fallback systems

RECOVERY_STATE="$HOME/.dotfiles-recovery"

# Detect current desktop environment
detect_desktop_environment() {
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || pgrep -x Hyprland &>/dev/null; then
        echo "hyprland"
    elif [[ -n "${SWAYSOCK:-}" ]] || pgrep -x sway &>/dev/null; then
        echo "sway"
    elif [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        echo "wayland"
    elif [[ -n "${DISPLAY:-}" ]]; then
        echo "x11"
    else
        echo "tty"
    fi
}

# Check if quickshell is working
check_quickshell() {
    if ! command -v quickshell &>/dev/null; then
        return 1
    fi

    # Check if config exists
    if [[ ! -f "$HOME/.config/quickshell/shell.qml" ]]; then
        return 1
    fi

    # Check if quickshell is running
    if pgrep -f quickshell &>/dev/null; then
        return 0
    fi

    return 1
}

# Enable fallback shell (waybar)
enable_fallback_shell() {
    log_section "Enabling Fallback Shell"

    # Ensure waybar is installed
    if ! command -v waybar &>/dev/null; then
        log_error "Waybar not installed, cannot fallback"
        return 1
    fi

    # Stop quickshell if running
    if pgrep -f quickshell &>/dev/null; then
        log_info "Stopping quickshell..."
        pkill -f quickshell
    fi

    # Disable quickshell autostart
    if [[ -f "$HOME/.config/hypr/conf/autostart.conf" ]]; then
        log_info "Disabling quickshell autostart..."
        sed -i 's/^exec-once.*quickshell/# &/' "$HOME/.config/hypr/conf/autostart.conf"
    fi

    # Enable waybar autostart
    if [[ -f "$HOME/.config/hypr/conf/autostart.conf" ]]; then
        if ! grep -q "exec-once.*waybar" "$HOME/.config/hypr/conf/autostart.conf"; then
            log_info "Enabling waybar autostart..."
            echo "exec-once = waybar" >> "$HOME/.config/hypr/conf/autostart.conf"
        fi
    fi

    # Start waybar now
    if ! pgrep -x waybar &>/dev/null; then
        log_info "Starting waybar..."
        waybar &>/dev/null &
    fi

    # Mark recovery state
    cat > "$RECOVERY_STATE" <<EOF
{
  "mode": "fallback",
  "timestamp": "$(date -Iseconds)",
  "reason": "quickshell_unavailable",
  "fallback_shell": "waybar"
}
EOF

    log_success "✓ Fallback shell enabled (waybar)"
    log_info "To restore quickshell: dotfiles recovery restore"

    return 0
}

# Restore quickshell from fallback
restore_quickshell() {
    log_section "Restoring QuickShell"

    if ! check_quickshell; then
        log_error "QuickShell is not properly configured"
        log_info "Run: dotfiles install"
        return 1
    fi

    # Re-enable quickshell autostart
    if [[ -f "$HOME/.config/hypr/conf/autostart.conf" ]]; then
        log_info "Re-enabling quickshell autostart..."
        sed -i 's/^# exec-once.*quickshell/exec-once = quickshell/' "$HOME/.config/hypr/conf/autostart.conf"
    fi

    # Disable waybar autostart
    if [[ -f "$HOME/.config/hypr/conf/autostart.conf" ]]; then
        log_info "Disabling waybar autostart..."
        sed -i 's/^exec-once.*waybar/# &/' "$HOME/.config/hypr/conf/autostart.conf"
    fi

    # Stop waybar
    if pgrep -x waybar &>/dev/null; then
        log_info "Stopping waybar..."
        pkill -x waybar
    fi

    # Start quickshell
    log_info "Starting quickshell..."
    quickshell &>/dev/null &

    # Clear recovery state
    rm -f "$RECOVERY_STATE"

    log_success "✓ QuickShell restored"

    return 0
}

# Enter recovery mode
enter_recovery_mode() {
    log_section "Entering Recovery Mode"

    # Create recovery state
    cat > "$RECOVERY_STATE" <<EOF
{
  "mode": "recovery",
  "timestamp": "$(date -Iseconds)",
  "desktop_environment": "$(detect_desktop_environment)"
}
EOF

    log_info "Recovery mode activated"
    echo
    log_info "Recovery commands:"
    echo "  dotfiles recovery status    - Show recovery status"
    echo "  dotfiles recovery fallback  - Enable fallback shell"
    echo "  dotfiles recovery restore   - Restore normal configuration"
    echo "  dotfiles install --resume   - Resume failed installation"
    echo "  dotfiles verify             - Verify system state"
}

# Show recovery status
show_recovery_status() {
    log_section "Recovery Status"

    if [[ ! -f "$RECOVERY_STATE" ]]; then
        log_info "System is not in recovery mode"
        return
    fi

    local mode timestamp reason
    mode=$(jq -r '.mode // "unknown"' "$RECOVERY_STATE")
    timestamp=$(jq -r '.timestamp // "unknown"' "$RECOVERY_STATE")
    reason=$(jq -r '.reason // "none"' "$RECOVERY_STATE")

    show_info "Mode" "$mode"
    show_info "Since" "$timestamp"
    show_info "Reason" "$reason"

    echo
    log_info "Desktop Environment: $(detect_desktop_environment)"

    echo
    log_info "Shell Status:"
    if check_quickshell; then
        echo "  ✓ QuickShell: Available and configured"
    else
        echo "  ✗ QuickShell: Not available"
    fi

    if command -v waybar &>/dev/null; then
        if pgrep -x waybar &>/dev/null; then
            echo "  ✓ Waybar: Running (fallback)"
        else
            echo "  - Waybar: Available but not running"
        fi
    else
        echo "  ✗ Waybar: Not installed"
    fi
}

# Auto-detect and fix common issues
auto_recover() {
    log_section "Auto Recovery"

    local issues_found=0
    local fixes_applied=0

    # Check quickshell
    if ! check_quickshell; then
        issues_found=$((issues_found + 1))
        log_warning "QuickShell not working properly"

        if command -v waybar &>/dev/null; then
            log_info "Enabling fallback shell..."
            if enable_fallback_shell; then
                fixes_applied=$((fixes_applied + 1))
            fi
        else
            log_error "No fallback shell available"
        fi
    fi

    # Check critical packages
    local missing_critical=()
    for pkg in hyprland kitty stow gum; do
        if ! command -v "$pkg" &>/dev/null && ! pacman -Qq "$pkg" &>/dev/null; then
            missing_critical+=("$pkg")
        fi
    done

    if [[ ${#missing_critical[@]} -gt 0 ]]; then
        issues_found=$((issues_found + 1))
        log_warning "Missing critical packages: ${missing_critical[*]}"
        log_info "Run: dotfiles install --resume"
    fi

    # Check configs
    local missing_configs=()
    for config in hypr kitty; do
        if [[ ! -L "$HOME/.config/$config" ]] && [[ ! -d "$HOME/.config/$config" ]]; then
            missing_configs+=("$config")
        fi
    done

    if [[ ${#missing_configs[@]} -gt 0 ]]; then
        issues_found=$((issues_found + 1))
        log_warning "Missing configs: ${missing_configs[*]}"
        log_info "Run: dotfiles config link"
    fi

    echo
    log_info "Auto-recovery summary:"
    log_info "  Issues found: $issues_found"
    log_success "  Fixes applied: $fixes_applied"

    if [[ $issues_found -eq 0 ]]; then
        log_success "System appears healthy"
    elif [[ $fixes_applied -eq $issues_found ]]; then
        log_success "All issues resolved"
    else
        log_warning "Some issues require manual intervention"
    fi
}

# Emergency shell (minimal working environment)
emergency_shell() {
    log_section "Emergency Shell"

    # Ensure basic terminal works
    if ! command -v kitty &>/dev/null; then
        log_error "Kitty not installed"

        # Try alternatives
        for term in alacritty foot wezterm; do
            if command -v "$term" &>/dev/null; then
                log_info "Using $term as fallback terminal"
                export TERMINAL="$term"
                break
            fi
        done
    fi

    # Minimal shell environment
    log_info "Setting up minimal shell environment..."

    # Disable fancy shell configs temporarily
    export SKIP_FANCY_SHELL=1

    # Launch minimal Hyprland config if needed
    if [[ "$(detect_desktop_environment)" == "tty" ]]; then
        log_info "Launching Hyprland with minimal config..."

        # Create minimal hyprland.conf
        local minimal_conf="/tmp/hyprland-minimal.conf"
        cat > "$minimal_conf" <<'EOF'
monitor=,preferred,auto,1
exec-once = kitty || alacritty || foot
input {
    kb_layout = us
    follow_mouse = 1
}
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
}
EOF

        Hyprland -c "$minimal_conf"
    fi

    log_success "Emergency shell ready"
}
