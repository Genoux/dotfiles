import QtQuick
import Quickshell
import qs
import qs.components
import qs.config
import qs.services

// Idle, the camera glyph. Recording, the glyph gives way to a dot and the
// running time; fills stay the ordinary button states either way.
// Either way a click opens the popover: the recording's controls live there,
// so the bar never stops a session by itself.
Button {
    id: root

    required property var screen
    required property var barWindow
    readonly property bool recording: CaptureState.recording
    readonly property bool paused: CaptureState.recordingPaused
    // Held through the collapse so the dot and time fade out with the width
    // instead of the camera glyph snapping back over them.
    property bool collapsing: false
    readonly property bool live: recording || collapsing

    iconSource: live ? "" : IconRegistry.captureIcon("idle")
    // Wider than the icon box: the dot and the time need air to read as a
    // pill rather than text squeezed between neighbours.
    paddingHorizontal: live ? StyleTokens.space8 : StyleControl.buttonPaddingHorizontal
    interactive: true
    active: capturePopover.open
    clipContent: true
    trailWidth: session.implicitWidth
    trailReveal: recording ? 1 : 0
    onClicked: capturePopover.toggle()
    onRecordingChanged: collapsing = !recording

    Behavior on trailReveal {
        NumberAnimation {
            duration: StyleRecording.expandDuration
            easing.type: StyleTokens.easeStandard
            onRunningChanged: {
                if (!running)
                    root.collapsing = false;
            }
        }
    }

    Row {
        id: session

        anchors.verticalCenter: parent.verticalCenter
        spacing: StyleTokens.space6
        opacity: root.trailReveal

        RecordingDot {
            anchors.verticalCenter: parent.verticalCenter
            paused: root.paused
        }

        Text {
            text: CaptureState.formatDuration(CaptureState.recordingSeconds)
            color: root.paused ? Colors.base04 : Colors.base05
            font.family: StyleTokens.fontMono
            font.pixelSize: StyleBar.labelFontSize
            height: root.labelLineHeight
            verticalAlignment: Text.AlignVCenter
        }
    }

    BarPopover {
        id: capturePopover

        barWindow: root.barWindow
        anchorItem: root

        CapturePopover {
            active: capturePopover.open
            onDismissRequested: capturePopover.dismissNow()
        }
    }
}
