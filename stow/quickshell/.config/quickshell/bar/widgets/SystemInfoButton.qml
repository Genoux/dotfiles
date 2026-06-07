import Quickshell.Io
import QtQuick
import qs.components

IconButton {
    iconName: "emblem-favorite-symbolic"
    interactive: true
    onClicked: clickProcess.running = true

    Process {
        id: clickProcess

        command: ["bash", "-lc", "hyprctl dispatch 'function() require(\"actions.launchers\").launchOrFocus(\"system-info\", \"fastfetch\", \"system-info\") end'"]
    }
}
