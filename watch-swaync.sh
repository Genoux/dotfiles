#!/bin/bash

# SwayNC auto-reload script
# Watches for changes in SwayNC config files and automatically reloads

SWAYNC_DIR="$HOME/.config/swaync"
CONFIG_FILE="$SWAYNC_DIR/config.json"
STYLE_FILE="$SWAYNC_DIR/style.css"

echo "🔄 Watching SwayNC files for changes..."
echo "📁 Config: $CONFIG_FILE"
echo "🎨 Style:  $STYLE_FILE"
echo "Press Ctrl+C to stop"

# Function to reload SwayNC
reload_swaync() {
    local file_changed="$1"
    echo "📝 $(basename "$file_changed") changed - reloading SwayNC..."
    
    if [[ "$file_changed" == *"config.json" ]]; then
        swaync-client --reload-config 2>/dev/null
        echo "✅ Config reloaded"
    elif [[ "$file_changed" == *"style.css" ]]; then
        swaync-client --reload-css 2>/dev/null
        echo "🎨 CSS reloaded"
    fi
}

# Watch both files using inotifywait
inotifywait -m -e modify,create,delete,move "$CONFIG_FILE" "$STYLE_FILE" 2>/dev/null | while read path action file; do
    reload_swaync "${path}${file}"
done