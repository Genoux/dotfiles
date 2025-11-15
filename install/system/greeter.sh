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

log_section "Greeter Setup"

# Check if sysc-greet is installed
if ! pacman -Q sysc-greet-hyprland &>/dev/null; then
    log_warning "sysc-greet-hyprland not installed - install packages first"
    log_info "Run: dotfiles packages install"
    exit 0
fi

log_info "Configuring sysc-greet greeter..."
echo

# Create greeter user if it doesn't exist
if ! id greeter &>/dev/null; then
    log_info "Creating greeter user..."
    sudo useradd -M -G video -s /usr/bin/nologin greeter
    log_success "Greeter user created"
else
    log_info "Greeter user already exists"
fi
echo

# Create necessary directories
log_info "Creating greeter directories..."
sudo mkdir -p /var/cache/sysc-greet
sudo mkdir -p /var/lib/greeter/Pictures/wallpapers
sudo chown -R greeter:greeter /var/cache/sysc-greet /var/lib/greeter
sudo chmod 755 /var/lib/greeter
log_success "Directories created"
echo

# Copy wallpapers if user has any
if [[ -d "$HOME/.config/hypr/wallpapers" ]]; then
    log_info "Copying user wallpapers to greeter..."
    sudo find "$HOME/.config/hypr/wallpapers" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) \
        -exec cp {} /usr/share/sysc-greet/wallpapers/ \; 2>/dev/null || true
    sudo chown -R greeter:greeter /usr/share/sysc-greet/wallpapers/
    log_success "Wallpapers copied"
    echo
fi

# Configure greetd
log_info "Configuring greetd service..."

# Backup existing config if it exists
if [[ -f /etc/greetd/config.toml ]]; then
    sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.backup
    log_info "Backed up existing config to /etc/greetd/config.toml.backup"
fi

# Create greetd config
sudo tee /etc/greetd/config.toml > /dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "Hyprland -c /etc/greetd/hyprland-greeter-config.conf"
user = "greeter"
EOF

log_success "greetd configured"
echo

# Check if Hyprland greeter config exists
if [[ ! -f /etc/greetd/hyprland-greeter-config.conf ]]; then
    log_warning "Hyprland greeter config not found at /etc/greetd/hyprland-greeter-config.conf"
    log_info "The sysc-greet-hyprland package should have installed this"
    log_info "You may need to create it manually or reinstall sysc-greet-hyprland"
else
    log_success "Hyprland greeter config found"
fi
echo

# Enable greetd service
log_info "Enabling greetd service..."
sudo systemctl enable greetd.service

# Check if greetd is already the active display manager
if systemctl is-active --quiet greetd.service; then
    log_success "greetd is already running as display manager"
elif systemctl is-active --quiet display-manager.service; then
    # Another display manager is active
    log_warning "Another display manager is currently running"
    log_info "To switch to greetd, you need to disable your current display manager"
    log_info "Example: sudo systemctl disable sddm.service"
    echo
    log_info "Then reboot to use sysc-greet greeter"
else
    log_success "greetd service enabled"
    log_info "Greeter will start on next boot"
fi

echo
log_success "Greeter setup complete"
echo
log_info "Configuration:"
log_info "  - Greeter: sysc-greet-hyprland"
log_info "  - Compositor: Hyprland"
log_info "  - Config: /etc/greetd/config.toml"
echo
log_info "To test the greeter without rebooting:"
log_info "  sysc-greet --test"
echo
log_info "Key bindings:"
log_info "  F1 - Settings (themes, borders, backgrounds)"
log_info "  F2 - Session selection"
log_info "  F3 - Release notes"
log_info "  F4 - Power menu"
