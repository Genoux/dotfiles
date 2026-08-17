pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool webcam: false
    property bool mic: false
    property bool monitorScreenAccess: false
    property bool processRecording: false
    property bool stopping: false
    property string webcamSource: ""
    property string micSource: ""
    property string screenSource: ""
    property int recordRevision: 0
    readonly property string recordStatePath: "/tmp/screenrecord.state"
    readonly property bool scriptRecording: {
        const _ = recordRevision;
        return recordStateFile.loaded && recordStateFile.text().trim() === "1";
    }
    readonly property bool rawRecording: scriptRecording || processRecording
    readonly property bool recording: rawRecording && !stopping
    readonly property bool screenAccess: monitorScreenAccess || recording
    readonly property bool anyActive: webcam || mic || screenAccess

    onRawRecordingChanged: {
        if (!rawRecording)
            stopping = false;
    }

    FileView {
        id: recordStateFile

        path: root.recordStatePath
        watchChanges: true
        printErrors: false
        onLoadedChanged: root.recordRevision++
        onFileChanged: {
            reload();
            root.recordRevision++;
        }
    }

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
                root.monitorScreenAccess = parts[2] === "1";
                root.processRecording = parts[3] === "1";
                root.webcamSource = fields[1] || "";
                root.micSource = fields[2] || "";
                root.screenSource = fields[3] || "";
            }
        }
    }
}
