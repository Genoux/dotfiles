#!/bin/bash
# Show completion message

# Wait a moment for screen to stabilize after Hyprland reload
sleep 1

# Clear screen (helpers already loaded by install.sh)
if command -v clear_screen &>/dev/null; then
    clear_screen
else
    clear
fi

if command -v gum &>/dev/null; then
    gum style \
        --border double \
        --border-foreground 10 \
        --padding "1 2" \
        --margin "1 0" \
        "$(gum style --bold --foreground 10 '✓ Installation Complete!')" \
        "" \
        "Your dotfiles have been successfully installed." \
        "" \
        "$(gum style --foreground 240 'Next steps:')" \
        "  • Log out and back in for shell changes" \
        "  • Start Hyprland: uwsm start hyprland-uwsm.desktop" \
        "  • Configure monitors: dotfiles hyprland setup" \
        "" \
        "$(gum style --foreground 240 'Daily commands:')" \
        "  • dotfiles status      # Show system state" \
        "  • dotfiles packages    # Manage packages" \
        "  • dotfiles theme       # Switch themes" \
        "" \
        "$(gum style --foreground 240 'Logs:')" \
        "  • $DOTFILES_LOG_FILE"
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✓ Installation Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Your dotfiles have been successfully installed."
    echo ""
    echo "Next steps:"
    echo "  • Log out and back in for shell changes"
    echo "  • Start Hyprland: uwsm start hyprland-uwsm.desktop"
    echo "  • Configure monitors: dotfiles hyprland setup"
    echo ""
    echo "Daily commands:"
    echo "  • dotfiles status      # Show system state"
    echo "  • dotfiles packages    # Manage packages"
    echo "  • dotfiles theme       # Switch themes"
    echo ""
    echo "Logs: $DOTFILES_LOG_FILE"
    echo ""
fi

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Wait for user acknowledgment
if command -v gum &>/dev/null; then
    gum style --foreground 14 "Press any key to continue..."
    read -n 1 -s -r
else
    read -n 1 -s -r -p "Press any key to continue..."
fi

echo
echo "Done! 🎉"

