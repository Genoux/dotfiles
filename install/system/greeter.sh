#!/bin/bash
# Greeter (sysc-greet) Setup
# Handles installation and configuration of sysc-greet login greeter

# Get dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Source helpers (always load to ensure functions are available)
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
else
    # Ensure helpers are sourced even if flag is set (might be from different shell)
    source "$DOTFILES_DIR/install/helpers/all.sh" 2>/dev/null || true
fi

log_section "Greeter"

# Check if sysc-greet is installed
if ! pacman -Q sysc-greet-hyprland &>/dev/null; then
    exit 0
fi

# Create greeter user if it doesn't exist
if ! id greeter &>/dev/null; then
    sudo useradd -M -G video -s /usr/bin/nologin greeter 2>/dev/null
    log_success "Greeter user created"
fi

# Create necessary directories
sudo mkdir -p /var/cache/sysc-greet /var/lib/greeter/Pictures/wallpapers /var/lib/greeter/.cache/sysc-greet 2>/dev/null
sudo chown -R greeter:greeter /var/cache/sysc-greet /var/lib/greeter 2>/dev/null
sudo chmod 755 /var/lib/greeter 2>/dev/null

# Deploy greeter preferences
if [[ -f "$DOTFILES_DIR/system/greetd/preferences.json" ]]; then
    sudo cp "$DOTFILES_DIR/system/greetd/preferences.json" /var/lib/greeter/.cache/sysc-greet/preferences 2>/dev/null
    sudo chown greeter:greeter /var/lib/greeter/.cache/sysc-greet/preferences 2>/dev/null
    log_success "Greeter preferences deployed"
fi

# Copy wallpapers if user has any
if [[ -d "$HOME/.config/hypr/wallpapers" ]]; then
    sudo find "$HOME/.config/hypr/wallpapers" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) \
        -exec cp {} /usr/share/sysc-greet/wallpapers/ \; 2>/dev/null || true
    sudo chown -R greeter:greeter /usr/share/sysc-greet/wallpapers/ 2>/dev/null
    log_success "Wallpapers copied"
fi

# Backup and create greetd config
if [[ -f /etc/greetd/config.toml ]]; then
    sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.backup 2>/dev/null
fi

sudo tee /etc/greetd/config.toml > /dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "Hyprland -c /etc/greetd/hyprland-greeter-config.conf"
user = "greeter"
EOF

log_success "greetd configured"

# Enable greetd service
sudo systemctl enable greetd.service 2>/dev/null

if systemctl is-active --quiet greetd.service; then
    log_success "greetd running"
fi
