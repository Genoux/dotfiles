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

# Universal merge function - works with any text format
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
    
    # Get format-specific markers from app config
    local start_marker=$(jq -r '.merge_markers.start // "# THEME_COLORS_START"' "$app_config")
    local end_marker=$(jq -r '.merge_markers.end // "# THEME_COLORS_END"' "$app_config")
    
    # Generate theme content with format-specific markers
    {
        echo "$start_marker"
        cat "$generated_file"
        echo "$end_marker"
    } > "$generated_file.with_markers"
    
    if [ -f "$target_file" ]; then
        # Replace existing section or append
        if grep -q "$start_marker" "$target_file"; then
            # Use awk for better handling of nested brackets
            awk -v start="$start_marker" -v end="$end_marker" '
                BEGIN { 
                    in_section = 0
                    bracket_count = 0 
                }
                $0 == start { 
                    in_section = 1
                    bracket_count = 0
                    next 
                }
                in_section && $0 == end {
                    # For exact string matches (like comments), stop immediately
                    if (start !~ /\{/ || end !~ /\}/) {
                        in_section = 0
                        next
                    }
                    # For bracket-based matches, check if we are at the right level
                    if (bracket_count == 0) {
                        in_section = 0
                        next
                    }
                }
                in_section {
                    # Count opening and closing braces for proper nesting
                    for (i = 1; i <= length($0); i++) {
                        char = substr($0, i, 1)
                        if (char == "{") bracket_count++
                        if (char == "}") bracket_count--
                    }
                    # If we hit the matching closing brace and end marker is "}"
                    if (bracket_count == 0 && end == "}" && $0 ~ /^\s*\}/) {
                        in_section = 0
                        next
                    }
                    next
                }
                !in_section { print }
            ' "$target_file" > "$target_file.tmp"
            cat "$target_file.tmp" "$generated_file.with_markers" > "$target_file"
            rm "$target_file.tmp"
        else
            # Append to end
            echo "" >> "$target_file"
            cat "$generated_file.with_markers" >> "$target_file"
        fi
    else
        # Create new file
        cat "$generated_file.with_markers" > "$target_file"
    fi
    
    # Cleanup
    rm "$generated_file.with_markers"
    success "Merged theme into $target_file"
}

# Universal generator - uses app-defined syntax patterns
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
log "Output directory: $OUTPUT_DIR"

# Process each app configuration
for app_config in "$APPS_DIR"/*.json; do
    if [ -f "$app_config" ]; then
        app_name=$(basename "$app_config" .json)
        filename=$(jq -r '.filename' "$app_config")
        output_file="$OUTPUT_DIR/$filename"
        
        log "Processing $app_name..."
        
        # Universal generation - no hardcoded app knowledge
        generate_theme_file "$app_config" "$output_file"
        
        success "Generated $filename"
        
        # Check if this app has a target file for merging
        target_file=$(jq -r '.target_file // empty' "$app_config")
        if [ -n "$target_file" ]; then
            merge_theme_into_target "$output_file" "$target_file" "$app_config"
        fi
    fi
done

success "Theme build completed successfully!"
log "Generated files are in: $OUTPUT_DIR"
log "You can now run your dotfiles.sh script to deploy with stow" 