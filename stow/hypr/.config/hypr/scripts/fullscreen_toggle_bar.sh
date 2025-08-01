#!/bin/bash

# Script to detect fullscreen windows and toggle AGS bar visibility
# This script monitors Hyprland events and hides/shows the AGS bar accordingly

BAR_NAME="Bar"
BAR_VISIBLE=true

hide_bar() {
    if [ "$BAR_VISIBLE" = true ]; then
        # Small delay to ensure smooth animation
        sleep 0.05
        ags toggle "$BAR_NAME"
        BAR_VISIBLE=false
        echo "Hiding bar"
    fi
}

show_bar() {
    if [ "$BAR_VISIBLE" = false ]; then
        # Small delay to ensure smooth animation  
        sleep 0.05
        ags toggle "$BAR_NAME"
        BAR_VISIBLE=true
        echo "Showing bar"
    fi
}

# Function to check if any window is fullscreen on current workspace
check_fullscreen() {
    local active_workspace=$(hyprctl activeworkspace -j | jq -r '.id')
    local fullscreen_count=$(hyprctl clients -j | jq --arg ws "$active_workspace" '[.[] | select(.workspace.id == ($ws | tonumber) and .fullscreen != 0)] | length')
    echo "Active workspace: $active_workspace, Fullscreen count on workspace: $fullscreen_count, Bar visible: $BAR_VISIBLE"
    
    if [ "$fullscreen_count" -gt 0 ]; then
        hide_bar
    else
        show_bar
    fi
}

# Initial check
check_fullscreen

# Monitor Hyprland events for fullscreen changes
socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r line; do
    echo "Event: $line"  # Debug output
    
    # Check for fullscreen events
    if echo "$line" | grep -q "fullscreen>>"; then
        echo "Fullscreen event detected"
        check_fullscreen
    fi
    
    # Also monitor workspace changes that might affect fullscreen
    if echo "$line" | grep -q "workspace>>"; then
        sleep 0.1
        check_fullscreen
    fi
done