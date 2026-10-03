import QtQuick
import qs
import qs.components
import qs.config
import qs.services as Services

// A recording is its own small island beside the main one, so the session never
// takes the clock's place. At rest it is only the dot; under the pointer it
// opens away from the island into the elapsed time and the controls, with the
// dot held where it was.
Rectangle {
    id: root

    readonly property bool paused: Services.CaptureState.recordingPaused
    readonly property bool open: hover.containsMouse
    // The controls sit as far from the trailing end as from the top and bottom,
    // so their hover fills are concentric with the capsule.
    readonly property real trailingInset: (height - stopButton.height) / 2

    implicitWidth: open ? StyleIsland.compactHeight + session.implicitWidth + trailingInset : StyleIsland.compactHeight
    implicitHeight: StyleIsland.compactHeight
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: StyleIsland.surface
    clip: true

    Behavior on width {
        NumberAnimation {
            duration: StyleIsland.resizeDuration
            easing.type: StyleIsland.plainEasing
        }
    }

    // The controls are its children, so pointing at them keeps it open.
    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor

        RecordingDot {
            anchors.left: parent.left
            anchors.leftMargin: (StyleIsland.compactHeight - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            paused: root.paused
        }

        Row {
            id: session

            anchors.left: parent.left
            anchors.leftMargin: StyleIsland.compactHeight
            anchors.verticalCenter: parent.verticalCenter
            spacing: StyleTokens.space2
            opacity: root.open ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: StyleTokens.motionFeedbackDuration
                    easing.type: StyleTokens.easeFade
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.CaptureState.formatDuration(Services.CaptureState.recordingSeconds)
                color: root.paused ? Colors.base04 : Colors.base05
                font.family: StyleTokens.fontMono
                font.pixelSize: StyleTokens.fontSizeSm
            }

            // A spacer rather than padding on the time, so a mirrored row keeps
            // the wider gap between the time and the controls.
            Item {
                width: StyleIsland.compactSpacing - parent.spacing * 2
                height: 1
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                interactive: true
                iconSource: IconRegistry.captureIcon(root.paused ? "resume" : "pause")
                onClicked: Services.CaptureState.togglePause()
            }

            Button {
                id: stopButton

                anchors.verticalCenter: parent.verticalCenter
                interactive: true
                iconSource: IconRegistry.captureIcon("stop")
                onClicked: Services.CaptureState.stopRecording()
            }
        }
    }
}
