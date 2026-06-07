import Quickshell.Io
import QtQuick
import qs.components
IconButton {
    id: root

    iconName: "network-offline-symbolic"
    interactive: true
    onClicked: clickProcess.running = true

    Process {
        id: stateProcess

        command: ["bash", "-lc", "ip route get 8.8.8.8 2>/dev/null | awk '{ for (i=1; i<=NF; i++) if ($i==\"dev\") { iface=$(i+1); if (iface ~ /^(wl|wlan)/ || iface ~ /wifi/) print \"network-wireless-symbolic\"; else print \"network-idle\"; found=1; exit } } END { if (!found) print \"network-offline-symbolic\" }'"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.iconName = this.text.trim() || "network-offline-symbolic"
        }
    }

    Process {
        id: clickProcess

        command: ["bash", "-lc", "hyprctl dispatch 'function() require(\"actions.launchers\").launchOrFocus(\"impala\", \"impala\", \"impala\") end'"]
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: stateProcess.running = true
    }
}
