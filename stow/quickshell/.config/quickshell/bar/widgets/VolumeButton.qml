import Quickshell.Io
import QtQuick
import qs.components
IconButton {
    id: root

    iconName: "audio-volume-high-symbolic"
    interactive: true
    onClicked: clickProcess.running = true

    Process {
        id: stateProcess

        command: ["bash", "-lc", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{ muted=($0 ~ /MUTED/); vol=$2+0; if (muted) print \"audio-volume-muted-symbolic\"; else if (vol > 0.66) print \"audio-volume-high-symbolic\"; else if (vol > 0.33) print \"audio-volume-medium-symbolic\"; else print \"audio-volume-low-symbolic\" }'"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.iconName = this.text.trim() || "audio-volume-high-symbolic"
        }
    }

    Process {
        id: clickProcess

        command: ["bash", "-lc", "hyprctl dispatch 'function() require(\"actions.launchers\").launchOrFocus(\"wiremix\", \"wiremix\", \"multimedia-volume-control\") end'"]
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: stateProcess.running = true
    }
}
