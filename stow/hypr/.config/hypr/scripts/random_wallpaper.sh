#!/bin/bash

# Config variables
WALLPAPER_DIR="$HOME/.config/hypr/wallpapers"
PEXELS_API_KEY="563492ad6f91700001000001c1afaf6a2f6249f0bb573dbbf644b92d" # Get this from https://www.pexels.com/api/
DOWNLOAD_DIR="$WALLPAPER_DIR/pexels"
FIXED_WALLPAPER="$DOWNLOAD_DIR/current_wallpaper.jpg" # Single fixed filename

# Create download directory if it doesn't exist
mkdir -p "$DOWNLOAD_DIR"

# Function to download a random wallpaper from Pexels
download_random_wallpaper() {
  # Random search terms for variety
  SEARCH_TERMS=("aerial")
  RANDOM_TERM=${SEARCH_TERMS[$RANDOM % ${#SEARCH_TERMS[@]}]}
  
  echo "Fetching a random high-quality $RANDOM_TERM wallpaper from Pexels..."
  
  # Query Pexels API
  RESPONSE=$(curl -s -H "Authorization: $PEXELS_API_KEY" \
    "https://api.pexels.com/v1/search?query=$RANDOM_TERM&orientation=landscape&size=4k&per_page=40")
  
  # Check if response contains photos
  if ! echo "$RESPONSE" | grep -q '"photos":'; then
    echo "Error: Failed to get images from Pexels API"
    return 1
  fi
  
  # Extract a random image URL (original size for high quality)
  IMAGE_URL=$(echo "$RESPONSE" | grep -o '"original":"[^"]*' | cut -d'"' -f4 | shuf -n 1)
  
  if [ -z "$IMAGE_URL" ]; then
    echo "Error: Could not extract image URL"
    return 1
  fi
  
  # Remove the existing file if it exists
  if [ -f "$FIXED_WALLPAPER" ]; then
    rm "$FIXED_WALLPAPER"
    echo "Removed previous wallpaper"
  fi
  
  # Download the image to the fixed filename
  echo "Downloading to: $FIXED_WALLPAPER"
  if curl -s "$IMAGE_URL" -o "$FIXED_WALLPAPER"; then
    echo "Downloaded new $RANDOM_TERM wallpaper"
    return 0
  else
    echo "Error: Failed to download image"
    return 1
  fi
}

# Main logic
# Give swww-daemon a moment to start if it just launched
sleep 1

# Try to download a new wallpaper
if download_random_wallpaper; then
  # Successfully downloaded, use it
  if [ -f "$FIXED_WALLPAPER" ]; then
    echo "Setting wallpaper: $FIXED_WALLPAPER"
    swww img "$FIXED_WALLPAPER" --transition-type grow --transition-pos 0.2,0.2 --transition-step 90
  else
    echo "Error: Wallpaper file not found at expected path"
    exit 1
  fi
else
  echo "Download failed, using local wallpaper instead..."
  
  # Get a list of all existing wallpapers from the local directory
  wallpapers=($(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) | grep -v "$DOWNLOAD_DIR"))
  
  # Check if any wallpapers were found
  if [ ${#wallpapers[@]} -eq 0 ]; then
    echo "No wallpapers found in $WALLPAPER_DIR"
    exit 1
  fi
  
  # Select a random wallpaper
  random_wallpaper=${wallpapers[$RANDOM % ${#wallpapers[@]}]}
  
  # Set the local wallpaper
  echo "Setting local wallpaper: $random_wallpaper"
  swww img "$random_wallpaper" --transition-type grow --transition-pos 0.2,0.2 --transition-step 90
fi

# Clean up any other files that might be in the pexels directory (from previous runs)
# This ensures we only ever have one file in the directory
find "$DOWNLOAD_DIR" -type f -not -name "$(basename "$FIXED_WALLPAPER")" -delete