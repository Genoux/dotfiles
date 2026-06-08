pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool webcam: false
    property bool mic: false
    property bool screenrecord: false
    readonly property bool anyActive: webcam || mic || screenrecord

    Process {
        command: [Quickshell.shellPath("assets/scripts/privacy-monitor.sh")]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                const parts = data.trim().split(":")
                if (parts.length !== 3) {
                    return
                }

                root.webcam = parts[0] === "1"
                root.mic = parts[1] === "1"
                root.screenrecord = parts[2] === "1"
            }
        }
    }
}
