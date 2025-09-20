#!/bin/bash

# Script to switch workspace and hide secret workspace if it's currently shown
# Usage: workspace-switch.sh <workspace_number>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <workspace_number>"
    exit 1
fi

WORKSPACE=$1

# Only hide special workspace if it's currently visible
SPECIAL_VISIBLE=$(hyprctl workspaces -j | jq -r '.[] | select(.name | startswith("special")) | .name' | head -1)
if [ -n "$SPECIAL_VISIBLE" ]; then
    hyprctl dispatch togglespecialworkspace
fi

# Switch to the target workspace
hyprctl dispatch workspace "$WORKSPACE"