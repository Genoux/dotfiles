#!/bin/bash

# Theme Build Script - Generates app-specific color files from base.json

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_JSON="$SCRIPT_DIR/base.json"
APPS_DIR="$SCRIPT_DIR/apps"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Function to normalize rgba string (remove spaces)
normalize_rgba() {
    local rgba="$1"
    echo "$rgba" | sed 's/ //g'
}

# Function to convert rgba to hex
rgba_to_hex() {
    local rgba="$1"
    rgba=$(normalize_rgba "$rgba")
    # Extract r, g, b, a values from rgba(r, g, b, a) or rgb(r,g,b)
    local values=$(echo "$rgba" | sed 's/.*(\(.*\))/\1/' | tr ',' ' ')
    read -r r g b _ <<< "$values"
    
    # Convert to integers and format as hex
    printf "#%02x%02x%02x" "$(printf "%.0f" "$r")" "$(printf "%.0f" "$g")" "$(printf "%.0f" "$b")"
}

# Function to convert rgba to rgba_hex (for Hyprland)
rgba_to_rgba_hex() {
    local rgba="$1"
    rgba=$(normalize_rgba "$rgba")
    # Extract r, g, b, a values from rgba(r, g, b, a) or rgb(r,g,b)
    local values=$(echo "$rgba" | sed 's/.*(\(.*\))/\1/' | tr ',' ' ')
    read -r r g b a <<< "$values"

    # if alpha is not set, default to 1
    if [ -z "$a" ]; then
        a=1
    fi
    
    # Convert alpha to 0-255 range and format as 0xRRGGBBAA
    local alpha_hex=$(printf "%02x" "$(printf "%.0f" "$(echo "$a * 255" | bc -l)")")
    printf "0x%02x%02x%02x%s" "$(printf "%.0f" "$r")" "$(printf "%.0f" "$g")" "$(printf "%.0f" "$b")" "$alpha_hex"
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

# Merge theme content into target files
merge_theme_into_target() {
    local generated_file="$1"
    local target_file="$2"
    local app_config="$3"
    
    # Skip if no target file specified
    if [ -z "$target_file" ] || [ "$target_file" = "null" ]; then
        return 0
    fi
    
    # Resolve target file path relative to script directory
    if [[ ! "$target_file" = /* ]]; then
        target_file="$SCRIPT_DIR/$target_file"
    fi
    
    # Create target directory if it doesn't exist
    mkdir -p "$(dirname "$target_file")"
    
    log "Merging theme into: $target_file"
    
    # Hard coded markers based on file extension
    local file_ext="${target_file##*.}"
    local start_marker=""
    local end_marker=""
    
    case "$file_ext" in
        "scss"|"css") 
            start_marker="/* ?!? */"
            end_marker="/* !?! */"
            ;;
        "conf"|"toml") 
            start_marker="# ?!?"
            end_marker="# !?!"
            ;;
        *) 
            start_marker="# ?!?"
            end_marker="# !?!"
            ;;
    esac
    
    # Generate theme content with format-specific markers
    {
        echo "$start_marker"
        cat "$generated_file"
        
        # Check if config specifies a footer to add after content
        local footer=$(jq -r '.syntax.footer // ""' "$app_config")
        if [[ -n "$footer" && "$footer" != "null" ]]; then
            echo "$footer"
        fi
        
        echo "$end_marker"
    } > "$generated_file.with_markers"
    
    if [ -f "$target_file" ]; then
        # Remove ALL existing theme sections using awk (more robust and handles special characters)
        awk -v start="$start_marker" -v end="$end_marker" '
        BEGIN { in_section = 0 }
        $0 == start { in_section = 1; next }
        $0 == end && in_section { in_section = 0; next }
        !in_section { print }
        ' "$target_file" > "$target_file.tmp"
        
        # Append new theme section
        cat "$target_file.tmp" "$generated_file.with_markers" > "$target_file"
        rm "$target_file.tmp"
    else
        # Create new file
        cat "$generated_file.with_markers" > "$target_file"
    fi
    
    # Cleanup
    rm "$generated_file.with_markers"
    success "Merged theme into $target_file"
}

# Generate theme content using app-defined syntax
generate_theme_file() {
    local app_config="$1"
    local output_file="$2"
    local format=$(jq -r '.format' "$app_config")
    
    # Get syntax patterns from app config
    local prefix=$(jq -r '.syntax.prefix // ""' "$app_config")
    local separator=$(jq -r '.syntax.separator // " = "' "$app_config")
    local suffix=$(jq -r '.syntax.suffix // ""' "$app_config")
    local header=$(jq -r '.syntax.header // "# Generated theme colors - DO NOT EDIT MANUALLY\\n# Generated from: {{BASE_FILE}}\\n# Generated at: {{DATE}}\\n"' "$app_config")
    
    # Process header template
    header=$(echo -e "$header" | sed "s/{{BASE_FILE}}/$(basename "$BASE_JSON")/g" | sed "s/{{DATE}}/$(date)/g")
    
    # Write header
    echo -e "$header" > "$output_file"
    
    # Generate variables
    jq -r '.variables | to_entries[] | "\(.key)=\(.value)"' "$app_config" | while IFS='=' read -r var_name color_key; do
        # Check if it's a literal value (starts with @) or color reference
        if [[ "$color_key" == @* ]]; then
            # Literal value - remove @ prefix and use as-is
            literal_value="${color_key#@}"
            echo "${prefix}${var_name}${separator}${literal_value}${suffix}" >> "$output_file"
        else
            # Color reference - look up in base.json
            color_value=$(jq -r ".colors.\"$color_key\"" "$BASE_JSON")
            if [ "$color_value" != "null" ]; then
                formatted_color=$(format_color "$color_value" "$format")
                
                # Handle TOML quoting
                if [[ "$separator" == *"="* ]] && [[ "$format" == "hex" ]] && [[ "$suffix" == "" ]]; then
                    formatted_color="\"$formatted_color\""
                fi
                
                echo "${prefix}${var_name}${separator}${formatted_color}${suffix}" >> "$output_file"
            else
                warning "Color key '$color_key' not found in base.json"
            fi
        fi
    done
}

log "Starting theme build process..."
log "Base colors: $BASE_JSON"

# Process each app configuration
for app_config in "$APPS_DIR"/*.json; do
    if [ -f "$app_config" ]; then
        app_name=$(basename "$app_config" .json)
        
        log "Processing $app_name..."
        
        # Check if this app has a target file for merging
        target_file=$(jq -r '.target_file // empty' "$app_config")
        if [ -n "$target_file" ]; then
            # Create temporary file for generated theme
            temp_file=$(mktemp)
            
            # Generate theme content
            generate_theme_file "$app_config" "$temp_file"
            
            # Merge directly into target
            merge_theme_into_target "$temp_file" "$target_file" "$app_config"
            
            # Cleanup temp file
            rm "$temp_file"
        else
            warning "No target file specified for $app_name - skipping"
        fi
    fi
done

success "Theme build completed successfully!" 