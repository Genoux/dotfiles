#!/bin/bash

# Theme Build Script
# Generates app-specific color files from base.json to stow/system/.config/themes/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_JSON="$SCRIPT_DIR/base.json"
APPS_DIR="$SCRIPT_DIR/apps"
OUTPUT_DIR="$SCRIPT_DIR/../stow/system/.config/themes"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[BUILD]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if base.json exists
if [ ! -f "$BASE_JSON" ]; then
    error "Base color file not found: $BASE_JSON"
    exit 1
fi

# Check if apps directory exists
if [ ! -d "$APPS_DIR" ]; then
    error "Apps directory not found: $APPS_DIR"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to normalize rgba string (remove spaces)
normalize_rgba() {
    local rgba="$1"
    echo "$rgba" | sed 's/ //g'
}

# Function to convert rgba to hex
rgba_to_hex() {
    local rgba="$1"
    rgba=$(normalize_rgba "$rgba")
    # Extract r, g, b, a values from rgba(r, g, b, a)
    local values=$(echo "$rgba" | sed 's/rgba(\([^)]*\))/\1/' | tr ',' ' ')
    read -r r g b a <<< "$values"
    
    # Convert to integers and format as hex
    printf "#%02x%02x%02x" $(printf "%.0f" "$r") $(printf "%.0f" "$g") $(printf "%.0f" "$b")
}

# Function to convert rgba to rgba_hex (for Hyprland)
rgba_to_rgba_hex() {
    local rgba="$1"
    rgba=$(normalize_rgba "$rgba")
    # Extract r, g, b, a values from rgba(r, g, b, a)
    local values=$(echo "$rgba" | sed 's/rgba(\([^)]*\))/\1/' | tr ',' ' ')
    read -r r g b a <<< "$values"
    
    # Convert alpha to 0-255 range and format as 0xRRGGBBAA
    local alpha_hex=$(printf "%02x" $(printf "%.0f" $(echo "$a * 255" | bc -l)))
    printf "0x%02x%02x%02x%s" $(printf "%.0f" "$r") $(printf "%.0f" "$g") $(printf "%.0f" "$b") "$alpha_hex"
}

# Function to format color based on format type
format_color() {
    local color_value="$1"
    local format="$2"
    
    case "$format" in
        "hex")
            rgba_to_hex "$color_value"
            ;;
        "rgba")
            normalize_rgba "$color_value"
            ;;
        "rgba_hex")
            rgba_to_rgba_hex "$color_value"
            ;;
        *)
            echo "$color_value"
            ;;
    esac
}

# Function to generate SCSS variables
generate_scss() {
    local app_config="$1"
    local output_file="$2"
    local format=$(jq -r '.format' "$app_config")
    
    echo "// Generated theme colors - DO NOT EDIT MANUALLY" > "$output_file"
    echo "// Generated from: $(basename "$BASE_JSON")" >> "$output_file"
    echo "// Generated at: $(date)" >> "$output_file"
    echo "" >> "$output_file"
    
    # Read variables from app config and generate SCSS
    jq -r '.variables | to_entries[] | "\(.key)=\(.value)"' "$app_config" | while IFS='=' read -r var_name color_key; do
        # Get color value from base.json
        color_value=$(jq -r ".colors.\"$color_key\"" "$BASE_JSON")
        if [ "$color_value" != "null" ]; then
            formatted_color=$(format_color "$color_value" "$format")
            echo "\$$var_name: $formatted_color;" >> "$output_file"
        else
            warning "Color key '$color_key' not found in base.json"
        fi
    done
}

generate_config() {
    local app_config="$1"
    local output_file="$2"
    local format=$(jq -r '.format' "$app_config")
    
    echo "# Generated theme colors - DO NOT EDIT MANUALLY" > "$output_file"
    echo "# Generated from: $(basename "$BASE_JSON")" >> "$output_file"
    echo "# Generated at: $(date)" >> "$output_file"
    echo "" >> "$output_file"
    
    # Read variables from app config and generate config
    jq -r '.variables | to_entries[] | "\(.key)=\(.value)"' "$app_config" | while IFS='=' read -r var_name color_key; do
        # Get color value from base.json
        color_value=$(jq -r ".colors.\"$color_key\"" "$BASE_JSON")
        if [ "$color_value" != "null" ]; then
            formatted_color=$(format_color "$color_value" "$format")
            echo "\$$var_name = $formatted_color" >> "$output_file"
        else
            warning "Color key '$color_key' not found in base.json"
        fi
    done
}

# Function to generate kitty config file (kitty format)
generate_kitty() {
    local app_config="$1"
    local output_file="$2"
    local format=$(jq -r '.format' "$app_config")
    
    echo "# Generated theme colors - DO NOT EDIT MANUALLY" > "$output_file"
    echo "# Generated from: $(basename "$BASE_JSON")" >> "$output_file"
    echo "# Generated at: $(date)" >> "$output_file"
    echo "" >> "$output_file"
    
    # Read variables from app config and generate kitty config
    jq -r '.variables | to_entries[] | "\(.key)=\(.value)"' "$app_config" | while IFS='=' read -r var_name color_key; do
        # Get color value from base.json
        color_value=$(jq -r ".colors.\"$color_key\"" "$BASE_JSON")
        if [ "$color_value" != "null" ]; then
            formatted_color=$(format_color "$color_value" "$format")
            echo "$var_name $formatted_color" >> "$output_file"
        else
            warning "Color key '$color_key' not found in base.json"
        fi
    done
}

# Function to generate TOML file
generate_toml() {
    local app_config="$1"
    local output_file="$2"
    local format=$(jq -r '.format' "$app_config")
    
    echo "# Generated theme colors - DO NOT EDIT MANUALLY" > "$output_file"
    echo "# Generated from: $(basename "$BASE_JSON")" >> "$output_file"
    echo "# Generated at: $(date)" >> "$output_file"
    echo "" >> "$output_file"
    echo "[palettes.custom]" >> "$output_file"
    
    # Read variables from app config and generate TOML
    jq -r '.variables | to_entries[] | "\(.key)=\(.value)"' "$app_config" | while IFS='=' read -r var_name color_key; do
        # Get color value from base.json
        color_value=$(jq -r ".colors.\"$color_key\"" "$BASE_JSON")
        if [ "$color_value" != "null" ]; then
            formatted_color=$(format_color "$color_value" "$format")
            echo "$var_name = \"$formatted_color\"" >> "$output_file"
        else
            warning "Color key '$color_key' not found in base.json"
        fi
    done
}

log "Starting theme build process..."
log "Base colors: $BASE_JSON"
log "Output directory: $OUTPUT_DIR"

# Process each app configuration
for app_config in "$APPS_DIR"/*.json; do
    if [ -f "$app_config" ]; then
        app_name=$(basename "$app_config" .json)
        filename=$(jq -r '.filename' "$app_config")
        output_file="$OUTPUT_DIR/$filename"
        
        log "Processing $app_name..."
        
        # Generate based on app name and file extension
        case "$filename" in
            *.scss)
                generate_scss "$app_config" "$output_file"
                ;;
            kitty-colors.conf)
                generate_kitty "$app_config" "$output_file"
                ;;
            *.conf)
                generate_config "$app_config" "$output_file"
                ;;
            *.toml)
                generate_toml "$app_config" "$output_file"
                ;;
            *)
                warning "Unknown file type for $filename, using config format"
                generate_config "$app_config" "$output_file"
                ;;
        esac
        
        success "Generated $filename"
    fi
done

success "Theme build completed successfully!"
log "Generated files are in: $OUTPUT_DIR"
log "You can now run your dotfiles.sh script to deploy with stow" 