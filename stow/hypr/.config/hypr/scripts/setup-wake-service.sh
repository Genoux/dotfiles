#!/bin/bash

# Script to set up systemd service for post-resume fixes

# Create the systemd service file
sudo tee /etc/systemd/system/hyprland-post-resume.service > /dev/null << 'EOF'
[Unit]
Description=Hyprland Post-Resume Fixes
After=suspend.target hibernate.target hybrid-sleep.target

[Service]
Type=oneshot
User=john
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=/home/john/.config/hypr/scripts/post-resume.sh
TimeoutSec=30

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target
EOF

# Enable the service
sudo systemctl daemon-reload
sudo systemctl enable hyprland-post-resume.service

echo "Systemd service created and enabled for post-resume fixes" 