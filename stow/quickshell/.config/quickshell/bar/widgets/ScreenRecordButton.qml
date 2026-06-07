import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import qs
import qs.config

Rectangle {
    id: root

    property bool recording: false
    property color recordingColor: "#47ff1c1c"

    implicitWidth: Style.pillHeight
    implicitHeight: Style.pillHeight
    radius: Style.radiusSm
    color: mouseArea.containsMouse
        ? (recording ? "#b9dc2929" : Style.alphaLight)
        : (recording ? recordingColor : Style.transparent)

    readonly property var iconSource: IconRegistry.source(root.recording ? "media-playback-stop-symbolic" : "media-optical-symbolic")
    readonly property bool usesLocalFile: iconSource.toString().startsWith("file:")

    Item {
        anchors.centerIn: parent
        width: Style.iconSizeSm
        height: Style.iconSizeSm

        Image {
            anchors.centerIn: parent
            visible: root.usesLocalFile
            width: parent.width
            height: parent.height
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(Style.iconSizeSm, Style.iconSizeSm)
            mipmap: true
        }

        IconImage {
            anchors.centerIn: parent
            visible: !root.usesLocalFile
            width: parent.width
            height: parent.height
            implicitSize: Style.iconSizeSm
            source: root.iconSource
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: clickProcess.running = true
    }

    SequentialAnimation {
        running: root.recording && !mouseArea.containsMouse
        loops: Animation.Infinite

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: "#a5ff1c1c"
            duration: 1000
            easing.type: Easing.InOutQuad
        }

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: "#47ff1c1c"
            duration: 1000
            easing.type: Easing.InOutQuad
        }
    }

    Process {
        id: stateProcess

        command: ["bash", "-lc", "pgrep -x wl-screenrec >/dev/null 2>&1 || pgrep -x wf-recorder >/dev/null 2>&1; printf $?"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.recording = this.text.trim() === "0"
        }
    }

    Process {
        id: clickProcess

        command: ["bash", "-lc", "if pgrep -x wl-screenrec >/dev/null 2>&1 || pgrep -x wf-recorder >/dev/null 2>&1; then system-screenrecord; else system-screenrecord region; fi"]
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: stateProcess.running = true
    }
}
