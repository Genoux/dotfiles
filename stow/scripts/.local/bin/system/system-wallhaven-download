#!/bin/bash
# Config variables
WALLPAPER_DIR="$HOME/.config/hypr/wallpapers"
WALLHAVEN_API_KEY="Nrr7caKYWR1gPHlRBlYMabQRSw8j6lKw" # Wallhaven API key
DOWNLOAD_DIR="$WALLPAPER_DIR/wallhaven"
FIXED_WALLPAPER="$DOWNLOAD_DIR/current_wallpaper.jpg" # Single fixed filename
TEMP_WALLPAPER="$DOWNLOAD_DIR/temp_wallpaper.jpg" # Temporary file for processing

# Search term - Change this to whatever you want to search for (can be overridden by config file)
# Empty string will get random safe wallpapers (no sketchy/nsfw/anime/people)
SEARCH_TERM="${SEARCH_TERM:-}"  # Default: empty for random safe wallpapers

# Parse command line arguments
# Check for config file, then environment variable, then default
CONFIG_FILE="$HOME/.config/hypr/wallpaper.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi
ENABLE_ROUNDED_CORNERS="${WALLPAPER_ROUNDED_CORNERS:-${ENABLE_ROUNDED_CORNERS:-true}}"
for arg in "$@"; do
    case $arg in
        --no-rounded|--flat|--full)
            ENABLE_ROUNDED_CORNERS=false
            echo "INFO: Rounded corners disabled - using full screen wallpaper"
            ;;
        --rounded)
            ENABLE_ROUNDED_CORNERS=true
            echo "INFO: Rounded corners enabled"
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --rounded        Enable rounded corners (default)"
            echo "  --no-rounded     Disable rounded corners (full screen)"
            echo "  --flat           Same as --no-rounded"
            echo "  --full           Same as --no-rounded"
            echo "  --help, -h       Show this help"
            exit 0
            ;;
    esac
done

# Function to auto-detect screen resolution and reserved space
get_screen_resolution() {
    local width=""
    local height=""
    local reserved_bottom=0
    
    # Method 1: Try hyprctl (Hyprland-specific, most accurate)
    if command -v hyprctl &> /dev/null; then
        local monitor_info=$(hyprctl monitors 2>/dev/null)
        if [ -n "$monitor_info" ]; then
            # Parse resolution more carefully
            local resolution_line=$(echo "$monitor_info" | grep -E '[0-9]+x[0-9]+@[0-9]+\.' | head -1)
            if [ -n "$resolution_line" ]; then
                # Extract just the resolution part before the @
                local resolution=$(echo "$resolution_line" | sed 's/^[[:space:]]*//' | cut -d'@' -f1)
                width=$(echo "$resolution" | cut -d'x' -f1)
                height=$(echo "$resolution" | cut -d'x' -f2)
                
                echo "DEBUG: Parsed resolution line: $resolution_line"
                echo "DEBUG: Extracted resolution: $resolution"
                echo "DEBUG: Width: $width, Height: $height"
            fi
            
            # Parse reserved space more carefully (format: "reserved: left top right bottom")
            local reserved_line=$(echo "$monitor_info" | grep "reserved:" | head -1)
            if [ -n "$reserved_line" ]; then
                # Extract all reserved values (after "reserved:")
                local reserved_values=$(echo "$reserved_line" | sed 's/.*reserved: //')
                local reserved_left=$(echo "$reserved_values" | awk '{print $1}')
                local reserved_top=$(echo "$reserved_values" | awk '{print $2}')
                local reserved_right=$(echo "$reserved_values" | awk '{print $3}')
                reserved_bottom=$(echo "$reserved_values" | awk '{print $4}')
                
                echo "DEBUG: Reserved line: $reserved_line"
                echo "DEBUG: Reserved values: left=$reserved_left top=$reserved_top right=$reserved_right bottom=$reserved_bottom"
                
                # Validate all reserved values are numbers
                if ! [[ "$reserved_left" =~ ^[0-9]+$ ]]; then reserved_left=0; fi
                if ! [[ "$reserved_top" =~ ^[0-9]+$ ]]; then reserved_top=0; fi
                if ! [[ "$reserved_right" =~ ^[0-9]+$ ]]; then reserved_right=0; fi
                if ! [[ "$reserved_bottom" =~ ^[0-9]+$ ]]; then reserved_bottom=0; fi
                
                # Store all reserved values globally
                RESERVED_LEFT="$reserved_left"
                RESERVED_TOP="$reserved_top"
                RESERVED_RIGHT="$reserved_right"
            fi
            
            # Validate width and height are numbers
            if ! [[ "$width" =~ ^[0-9]+$ ]] || ! [[ "$height" =~ ^[0-9]+$ ]]; then
                echo "DEBUG: Width '$width' or height '$height' is not valid, clearing values"
                width=""
                height=""
            fi
            
            if [ -n "$width" ] && [ -n "$height" ]; then
                echo "DEBUG: Screen resolution detected via hyprctl: ${width}x${height}"
                echo "DEBUG: Reserved space: ${reserved_bottom}px at bottom"
            fi
        fi
    fi
    
    # Method 2: Try wlr-randr (Wayland)
    if [ -z "$width" ] && command -v wlr-randr &> /dev/null; then
        local resolution=$(wlr-randr | grep -E '^\s*[0-9]+x[0-9]+' | head -1 | awk '{print $1}')
        if [ -n "$resolution" ]; then
            width=$(echo "$resolution" | cut -d'x' -f1)
            height=$(echo "$resolution" | cut -d'x' -f2)
            echo "DEBUG: Screen resolution detected via wlr-randr: ${width}x${height}"
        fi
    fi
    
    # Method 3: Try xrandr (fallback)
    if [ -z "$width" ] && command -v xrandr &> /dev/null; then
        local resolution=$(xrandr | grep -E '^\s*[0-9]+x[0-9]+.*\*' | head -1 | awk '{print $1}')
        if [ -n "$resolution" ]; then
            width=$(echo "$resolution" | cut -d'x' -f1)
            height=$(echo "$resolution" | cut -d'x' -f2)
            echo "DEBUG: Screen resolution detected via xrandr: ${width}x${height}"
        fi
    fi
    
    # Fallback to default if detection failed
    if [ -z "$width" ] || [ -z "$height" ]; then
        width=1920
        height=1080
        reserved_bottom=40
        echo "DEBUG: Could not detect screen resolution, using default: ${width}x${height}"
        echo "DEBUG: Using default reserved space: ${reserved_bottom}px"
    fi
    
    # Ensure all values are valid numbers
    SCREEN_WIDTH="${width:-1920}"
    SCREEN_HEIGHT="${height:-1080}"
    RESERVED_LEFT="${RESERVED_LEFT:-0}"
    RESERVED_TOP="${RESERVED_TOP:-0}"
    RESERVED_RIGHT="${RESERVED_RIGHT:-0}"
    RESERVED_BOTTOM="${reserved_bottom:-40}"
    
    echo "DEBUG: Final values - Width: $SCREEN_WIDTH, Height: $SCREEN_HEIGHT"
    echo "DEBUG: Reserved space - Left: $RESERVED_LEFT, Top: $RESERVED_TOP, Right: $RESERVED_RIGHT, Bottom: $RESERVED_BOTTOM"
}

# Auto-detect screen resolution
get_screen_resolution

# Simple clean rounded corners settings (can be overridden by config file)
CORNER_RADIUS="${CORNER_RADIUS:-24}"          # Radius for all corners (clean and minimal)
MARGIN_TOP="${MARGIN_TOP:-0}"                 # Space from top edge
MARGIN_LEFT="${MARGIN_LEFT:-0}"               # Space from left edge  
MARGIN_RIGHT="${MARGIN_RIGHT:-0}"             # Space from right edge
MARGIN_BOTTOM="${MARGIN_BOTTOM:-0}"           # Space from bottom (set to 0 since reserved space is auto-handled)
BACKGROUND_COLOR="${BACKGROUND_COLOR:-#11111b}" # Color that shows in the margins/corners
# SCREEN_WIDTH, SCREEN_HEIGHT are set automatically above
# RESERVED_BOTTOM is detected but not used (Hyprland handles it automatically)

# Create download directory if it doesn't exist
mkdir -p "$DOWNLOAD_DIR"

# Function to apply wallpaper effects (rounded corners or full screen)
apply_rounded_corners() {
    local input_file="$1"
    local output_file="$2"
    
    # Check if rounded corners are disabled
    if [ "$ENABLE_ROUNDED_CORNERS" = "false" ]; then
        echo "Applying full screen wallpaper (no rounded corners)..."
        # Just resize to full screen and copy
        if command -v magick &> /dev/null; then
            MAGICK_CMD="magick"
        elif command -v convert &> /dev/null; then
            MAGICK_CMD="convert"
        else
            echo "Warning: ImageMagick not found. Using original image..."
            cp "$input_file" "$output_file"
            return 0
        fi
        
        # Resize to full screen
        $MAGICK_CMD "$input_file" -resize "${SCREEN_WIDTH}x${SCREEN_HEIGHT}^" -gravity center -extent "${SCREEN_WIDTH}x${SCREEN_HEIGHT}" "$output_file"
        
        if [ $? -eq 0 ] && [ -s "$output_file" ]; then
            echo "Successfully created full screen wallpaper: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
            return 0
        else
            echo "Error creating full screen wallpaper, using original image"
            cp "$input_file" "$output_file"
            return 1
        fi
    fi
    
    # Continue with rounded corners logic
    # Auto-calculate margins from reserved space (add a bit of padding)
    local auto_margin_top=$((RESERVED_TOP + MARGIN_TOP))
    local auto_margin_left=$((RESERVED_LEFT + MARGIN_LEFT))
    local auto_margin_right=$((RESERVED_RIGHT + MARGIN_RIGHT))
    local auto_margin_bottom=$((RESERVED_BOTTOM + MARGIN_BOTTOM + 3))
    
    echo "Applying clean rounded corners (radius: ${CORNER_RADIUS}px)..."
    echo "DEBUG: Physical screen: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
    echo "DEBUG: Reserved space - T:${RESERVED_TOP} L:${RESERVED_LEFT} R:${RESERVED_RIGHT} B:${RESERVED_BOTTOM}"
    echo "DEBUG: Auto-calculated margins - T:${auto_margin_top} L:${auto_margin_left} R:${auto_margin_right} B:${auto_margin_bottom}"
    echo "DEBUG: Background color: ${BACKGROUND_COLOR}"
    
    # Check if ImageMagick is installed
    if command -v magick &> /dev/null; then
        MAGICK_CMD="magick"
    elif command -v convert &> /dev/null; then
        MAGICK_CMD="convert"
    else
        echo "Warning: ImageMagick not found. Skipping effects..."
        cp "$input_file" "$output_file"
        return 0
    fi
    
    # Calculate the image area (full screen minus all margins)
    local image_width=$((SCREEN_WIDTH - auto_margin_left - auto_margin_right))
    local image_height=$((SCREEN_HEIGHT - auto_margin_top - auto_margin_bottom))
    local image_right=$((auto_margin_left + image_width - 1))
    local image_bottom=$((auto_margin_top + image_height - 1))
    
    echo "DEBUG: Image area: ${image_width}x${image_height} at position ${auto_margin_left},${auto_margin_top}"
    echo "DEBUG: Image bounds: ${auto_margin_left},${auto_margin_top} to ${image_right},${image_bottom}"
    
    # Create FULL SIZE wallpaper (swww expects this) with rounded image area
    # Step 1: Extract dominant dark color from the image for background
    echo "DEBUG: Extracting dominant dark color from image..."
    
    # Get the darkest colors from the image and pick the most common one
    local extracted_color=$($MAGICK_CMD "$input_file" -resize 100x100! -colors 16 -depth 8 -format "%c" histogram:info: | \
        grep -E "^\s*[0-9]+:" | \
        while read line; do
            # Extract hex color from the line
            hex_color=$(echo "$line" | grep -o "#[0-9A-Fa-f]\{6\}")
            if [ -n "$hex_color" ]; then
                # Convert hex to RGB and calculate brightness
                r=$((0x${hex_color:1:2}))
                g=$((0x${hex_color:3:2}))
                b=$((0x${hex_color:5:2}))
                brightness=$(((r * 299 + g * 587 + b * 114) / 1000))
                
                # Only consider very dark colors (brightness < 80 for darker selection)
                if [ $brightness -lt 80 ]; then
                    pixel_count=$(echo "$line" | grep -o "^\s*[0-9]\+" | tr -d ' ')
                    echo "$brightness $pixel_count $hex_color"
                fi
            fi
        done | sort -n | head -1 | awk '{print $3}')
    
    # Use extracted color and make it even darker for better contrast
    if [ -n "$extracted_color" ]; then
        echo "DEBUG: Extracted base color: ${extracted_color}"
        
        # Convert hex to RGB
        r=$((0x${extracted_color:1:2}))
        g=$((0x${extracted_color:3:2}))
        b=$((0x${extracted_color:5:2}))
        
        # Darken by reducing each component by 30% (multiply by 0.7)
        r=$(( (r * 7) / 10 ))
        g=$(( (g * 7) / 10 ))
        b=$(( (b * 7) / 10 ))
        
        # Ensure values don't go below 0
        [ $r -lt 0 ] && r=0
        [ $g -lt 0 ] && g=0
        [ $b -lt 0 ] && b=0
        
        # Convert back to hex
        BACKGROUND_COLOR=$(printf "#%02x%02x%02x" $r $g $b)
        echo "DEBUG: Darkened background color: ${BACKGROUND_COLOR} (from ${extracted_color})"
    else
        echo "DEBUG: Could not extract color, using default: ${BACKGROUND_COLOR}"
    fi
    
    # Step 2: Create background canvas with the extracted/chosen color
    $MAGICK_CMD -size "${SCREEN_WIDTH}x${SCREEN_HEIGHT}" xc:"${BACKGROUND_COLOR}" /tmp/bg_canvas.png
    
    # Step 3: Resize and crop the wallpaper to fit the image area
    $MAGICK_CMD "$input_file" -resize "${image_width}x${image_height}^" -gravity center -extent "${image_width}x${image_height}" /tmp/resized_img.png
    
    # Step 4: Create a simple approach - use ImageMagick's built-in rounded rectangle
    # Draw a rounded rectangle with the image as fill on the background canvas
    
    echo "DEBUG: Creating rounded rectangle with image fill..."
    
    # Create a rounded rectangle path (only bottom corners rounded)
    local corner_start_y=$((image_bottom - CORNER_RADIUS))
    local path="M ${auto_margin_left},${auto_margin_top}"
    path="${path} L ${image_right},${auto_margin_top}"
    path="${path} L ${image_right},${corner_start_y}"
    path="${path} Q ${image_right},${image_bottom} $((image_right - CORNER_RADIUS)),${image_bottom}"
    path="${path} L $((auto_margin_left + CORNER_RADIUS)),${image_bottom}"
    path="${path} Q ${auto_margin_left},${image_bottom} ${auto_margin_left},${corner_start_y}"
    path="${path} Z"
    
    echo "DEBUG: Rounded rectangle path: ${path}"
    
    # Use the resized image as a tile pattern and draw the rounded rectangle
    $MAGICK_CMD /tmp/bg_canvas.png \
        \( /tmp/resized_img.png -write mpr:tile +delete \) \
        -tile mpr:tile \
        -draw "path '${path}'" \
        "$output_file"
    
    # DEBUG: Save intermediate files for inspection
    echo "DEBUG: Saving debug files to /tmp/ for inspection:"
    echo "  - /tmp/debug_bg_canvas.png (background)"
    echo "  - /tmp/debug_resized_img.png (resized image)"
    echo "  - /tmp/debug_mask.png (mask)"
    echo "  - /tmp/debug_rounded_img.png (rounded image)"
    cp /tmp/bg_canvas.png /tmp/debug_bg_canvas.png 2>/dev/null
    cp /tmp/resized_img.png /tmp/debug_resized_img.png 2>/dev/null
    cp /tmp/mask.png /tmp/debug_mask.png 2>/dev/null
    cp /tmp/rounded_img.png /tmp/debug_rounded_img.png 2>/dev/null
    
    # Clean up temp files
    rm -f /tmp/bg_canvas.png /tmp/resized_img.png
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && [ -s "$output_file" ]; then
        echo "Successfully applied clean rounded corners"
        echo "DEBUG: Created full-size wallpaper: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
        echo "DEBUG: With rounded image area that avoids taskbar"
        return 0
    else
        echo "Error applying rounded corners, using original image"
        cp "$input_file" "$output_file"
        return 1
    fi
}

# Function to download a wallpaper from Wallhaven or direct URL
download_random_wallpaper() {
    local selected_url="$SEARCH_TERM"
    
    # Check if SEARCH_TERM contains multiple URLs (space or comma separated)
    if [[ "$SEARCH_TERM" =~ https?:// ]] && [[ "$SEARCH_TERM" =~ [[:space:],].*https?:// ]]; then
        echo "Multiple URLs detected, selecting one randomly..."
        # Split by space or comma and filter URLs
        local urls=()
        IFS=$' \t\n,' read -ra ADDR <<< "$SEARCH_TERM"
        for url in "${ADDR[@]}"; do
            # Trim whitespace
            url=$(echo "$url" | xargs)
            if [[ "$url" =~ ^https?:// ]]; then
                urls+=("$url")
            fi
        done
        
        if [ ${#urls[@]} -gt 0 ]; then
            # Pick random URL from array
            local random_index=$((RANDOM % ${#urls[@]}))
            selected_url="${urls[$random_index]}"
            echo "Selected URL ($((random_index + 1)) of ${#urls[@]}): $selected_url"
        else
            echo "Error: No valid URLs found in input"
            return 1
        fi
    fi
    
    # Check if selected_url is a URL
    if [[ "$selected_url" =~ ^https?:// ]]; then
        # Check if it's a Wallhaven page URL
        if [[ "$selected_url" =~ wallhaven\.cc/w/ ]]; then
            echo "Extracting image from Wallhaven page: '$selected_url'"
            # Extract the wallpaper ID from the URL (e.g., gwjq3d from https://wallhaven.cc/w/gwjq3d)
            local wallpaper_id=$(echo "$selected_url" | grep -o '/w/[^/]*' | cut -d'/' -f3)
            if [ -n "$wallpaper_id" ]; then
                echo "Getting image URL for wallpaper ID: $wallpaper_id"
                # Use Wallhaven API to get the actual image URL
                local api_url="https://wallhaven.cc/api/v1/w/${wallpaper_id}"
                RESPONSE=$(curl -s "$api_url")
                IMAGE_URL=$(echo "$RESPONSE" | jq -r '.data.path' 2>/dev/null)
                if [ "$IMAGE_URL" = "null" ] || [ -z "$IMAGE_URL" ]; then
                    echo "Error: Could not extract image URL from Wallhaven page"
                    return 1
                fi
                echo "Found image URL: $IMAGE_URL"
            else
                echo "Error: Could not extract wallpaper ID from URL"
                return 1
            fi
        else
            echo "Using direct image URL: '$selected_url'"
            IMAGE_URL="$selected_url"
        fi
    else
        # Handle empty search term - get random safe wallpapers
        if [ -z "$SEARCH_TERM" ] || [ "$SEARCH_TERM" = " " ]; then
            echo "Getting random safe wallpaper (no sketchy/nsfw/anime/people content)"
            # Build Wallhaven API URL for random safe content
            # categories: 100 = General only (no Anime/People)
            # purity: 100 = SFW only (no Sketchy/NSFW)
            local base_url="https://wallhaven.cc/api/v1/search"
            local api_url="${base_url}?apikey=${WALLHAVEN_API_KEY}&categories=100&purity=100&sorting=random"
        else
            echo "Searching Wallhaven for: '$SEARCH_TERM'"
            # Build Wallhaven API URL
            local base_url="https://wallhaven.cc/api/v1/search"
            local encoded_query=$(echo "$SEARCH_TERM" | sed 's/ /%20/g')
            local api_url="${base_url}?apikey=${WALLHAVEN_API_KEY}&q=${encoded_query}&categories=100&purity=100&sorting=random"
        fi
        
        # Make API request
        RESPONSE=$(curl -s "$api_url")
        
        # Check if we got results
        if ! echo "$RESPONSE" | grep -q '"data":' || [ "$(echo "$RESPONSE" | jq -r '.data | length' 2>/dev/null)" = "0" ]; then
            echo "No wallpapers found for search term: '$SEARCH_TERM'"
            return 1
        fi
        
        # Get the highest resolution wallpaper
        if command -v jq &> /dev/null; then
            IMAGE_URL=$(echo "$RESPONSE" | jq -r '.data[] | "\(.dimension_x)x\(.dimension_y) \(.path)"' | \
                awk '{pixels = $1; gsub(/x/, "*", pixels); print pixels " " $2}' | \
                sort -nr | head -1 | awk '{print $2}')
        else
            IMAGE_URL=$(echo "$RESPONSE" | grep -o '"path":"[^"]*' | cut -d'"' -f4 | head -1)
        fi
        
        if [ -z "$IMAGE_URL" ]; then
            echo "Error: Could not extract wallpaper URL"
            return 1
        fi
    fi
    
    echo "Downloading wallpaper from: $IMAGE_URL"
    
    # Clean up old files
    rm -f "$FIXED_WALLPAPER" "$TEMP_WALLPAPER"
    
    # Download wallpaper
    if curl -s "$IMAGE_URL" -o "$TEMP_WALLPAPER"; then
        # Apply rounded corners
        apply_rounded_corners "$TEMP_WALLPAPER" "$FIXED_WALLPAPER"
        rm -f "$TEMP_WALLPAPER"
        return 0
    else
        echo "Error: Failed to download wallpaper"
        return 1
    fi
}



# Main logic
# Give swww-daemon a moment to start if it just launched
sleep 1

echo "=== Wallpaper Downloader ==="
if [[ "$SEARCH_TERM" =~ ^https?:// ]]; then
    echo "URL: '$SEARCH_TERM'"
elif [ -z "$SEARCH_TERM" ] || [ "$SEARCH_TERM" = " " ]; then
    echo "Mode: Random safe wallpaper"
else
    echo "Search: '$SEARCH_TERM'"
fi
if [ "$ENABLE_ROUNDED_CORNERS" = "true" ]; then
    echo "Mode: Rounded corners (${CORNER_RADIUS}px radius)"
else
    echo "Mode: Full screen (no rounded corners)"
fi
echo "=============================="

# Download and set wallpaper
if download_random_wallpaper; then
    if [ -f "$FIXED_WALLPAPER" ]; then
        echo "Setting wallpaper..."
        swww img "$FIXED_WALLPAPER" --transition-type grow --transition-pos 0.2,0.2 --transition-step 90
        echo "Done!"
    else
        echo "Error: Wallpaper file not found"
        exit 1
    fi
else
    echo "Failed to find wallpaper for search term: '$SEARCH_TERM'"
    exit 1
fi

# Clean up any other files that might be in the wallhaven directory (from previous runs)
# This ensures we only ever have one file in the directory
find "$DOWNLOAD_DIR" -type f -not -name "$(basename "$FIXED_WALLPAPER")" -delete