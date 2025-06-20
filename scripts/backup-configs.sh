#!/bin/bash

# Copies system configs to dotfiles for stow management

STOW_DIR="$HOME/dotfiles/stow"
SOURCE_CONFIG="$HOME/.config"

echo "📦 Backing up configs with GNU Stow structure..."

# Install stow if needed
if ! command -v stow &> /dev/null; then
    echo "Installing GNU Stow..."
    sudo pacman -S stow
fi

# Create stow directory
mkdir -p "$STOW_DIR"

# # List of configs to backup (add/remove as needed)
# configs=(
#     "hypr"           # Window manager
#     "ags"            # AGS editor
#     "kitty"          # Terminal
#     "nvim"           # Editor
#     "gtk-3.0"        # GTK3 theme
#     "gtk-4.0"        # GTK4 theme
#     "fastfetch"      # System info
#     "cava"           # Audio visualizer
#     "yazi"           # File manager
# )

# # Files (not directories)
# files=(
#     "mimeapps.list"
#     "user-dirs.dirs"
# )

echo "🔍 Scanning your ~/.config..."
echo

found_configs=()
missing_configs=()

# Check what configs you actually have
for config in "${configs[@]}"; do
    if [[ -e "$SOURCE_CONFIG/$config" ]]; then
        size=$(du -sh "$SOURCE_CONFIG/$config" 2>/dev/null | cut -f1)
        echo "✓ Found: $config ($size)"
        found_configs+=("$config")
    else
        echo "✗ Missing: $config"
        missing_configs+=("$config")
    fi
done

echo
echo "📊 Summary:"
echo "  Found configs: ${#found_configs[@]}"
echo "  Missing configs: ${#missing_configs[@]}"

if [[ ${#found_configs[@]} -eq 0 ]]; then
    echo "❌ No configs found to backup!"
    exit 1
fi

echo
read -p "Backup these ${#found_configs[@]} configs? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Backup cancelled."
    exit 0
fi

# Backup found configs
echo "📦 Backing up configs..."
cd "$STOW_DIR"

for config in "${found_configs[@]}"; do
    echo "📁 Backing up $config..."
    
    # Create package directory (use config name as package name)
    package_dir="$config"
    mkdir -p "$package_dir/.config"
    
    # Remove old backup
    rm -rf "$package_dir/.config/$config"
    
    # Copy config
    cp -r "$SOURCE_CONFIG/$config" "$package_dir/.config/"
    
    echo "  ✓ $config -> $package_dir"
done

# Backup files
echo "📄 Backing up config files..."
mkdir -p "system/.config"
for file in "${files[@]}"; do
    if [[ -f "$SOURCE_CONFIG/$file" ]]; then
        cp "$SOURCE_CONFIG/$file" "system/.config/"
        echo "  ✓ $file -> system"
    fi
done

echo
echo "✅ Backup complete!"
echo
echo "📁 Location: $STOW_DIR"
echo "📦 Configs backed up: ${#found_configs[@]}"
echo
echo "💡 Next steps:"
echo "  cd $STOW_DIR"
echo "  ./manage-configs.sh list"
echo "  ./manage-configs.sh install hypr"
echo "  ./manage-configs.sh install all"