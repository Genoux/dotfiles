pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool webcam: false
    property bool mic: false
    property bool screenAccess: false
    property bool recording: false
    property string webcamSource: ""
    property string micSource: ""
    property string screenSource: ""
    readonly property bool anyActive: webcam || mic || screenAccess

    Process {
        command: [Quickshell.shellPath("assets/scripts/privacy-monitor.sh")]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                const fields = data.trim().split("\t");
                const parts = (fields[0] || "").split(":");
                if (parts.length !== 4) {
                    return;
                }

                root.webcam = parts[0] === "1";
                root.mic = parts[1] === "1";
                root.screenAccess = parts[2] === "1";
                root.recording = parts[3] === "1";
                root.webcamSource = fields[1] || "";
                root.micSource = fields[2] || "";
                root.screenSource = fields[3] || "";
            }
        }
    }
}
