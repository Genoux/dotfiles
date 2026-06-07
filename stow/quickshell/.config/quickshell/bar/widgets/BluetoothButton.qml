import Quickshell.Io
import QtQuick
import qs.components
IconButton {
    id: root

    property bool powered: false

    visible: powered
    iconName: "bluetooth-active-symbolic"
    interactive: true
    onClicked: clickProcess.running = true

    Process {
        id: stateProcess

        command: ["bash", "-lc", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo yes || echo no"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.powered = this.text.trim() === "yes"
        }
    }

    Process {
        id: clickProcess

        command: ["bash", "-lc", "blueman-manager"]
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: stateProcess.running = true
    }
}
