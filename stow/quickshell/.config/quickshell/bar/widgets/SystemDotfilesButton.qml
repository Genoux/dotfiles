import Quickshell.Io
import QtQuick
import qs
import qs.components
IconButton {
    id: root

    property bool updatesAvailable: false

    interactive: true
    iconName: "input-keyboard"
    onClicked: clickProcess.running = true

    Rectangle {
        visible: root.updatesAvailable
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 4
        anchors.topMargin: 4
        width: 5
        height: 5
        radius: 999
        color: Colors.base0D
    }

    Process {
        id: stateProcess

        command: ["bash", "-lc", "grep -q '^UPDATES_AVAILABLE=true' \"$HOME/.local/state/dotfiles/updates.state\" 2>/dev/null && echo yes || echo no"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.updatesAvailable = this.text.trim() === "yes"
        }
    }

    Process {
        id: clickProcess

        command: ["launch-dotfiles-menu"]
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: stateProcess.running = true
    }
}
