import QtQuick
import qs
import qs.config

// A real switch: the knob's position states the value, so the control says what
// it IS rather than needing a word to say it. Replaces the "On"/"Off" PillButton
// in panel headers, where that pill read as a button you press to get somewhere
// rather than a state you are looking at.
//
// Monochrome on purpose. The shell carries state in weight and fill rather than
// accent colour, so "on" is a bright track with a dark knob and "off" is the
// same faint tint every other resting control wears.
Rectangle {
    id: control

    property bool checked: false
    property bool interactive: true

    signal toggled()

    implicitWidth: StyleControl.toggleWidth
    implicitHeight: StyleControl.toggleHeight
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: control.checked ? Colors.base05 : StyleTokens.alphaLight
    border.width: StyleTokens.borderWidth
    border.color: control.checked ? StyleTokens.transparent : StyleOverlay.borderSubtle
    opacity: control.interactive ? 1 : StyleTokens.opacityDisabled

    Behavior on color {
        ColorAnimation {
            duration: StyleTokens.easeDurationFast
            easing.type: StyleTokens.easeSymmetric
        }
    }

    Rectangle {
        id: knob

        width: control.height - StyleControl.toggleInset * 2
        height: width
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        x: control.checked
            ? control.width - width - StyleControl.toggleInset
            : StyleControl.toggleInset
        // Dark against a lit track, muted against an unlit one — legible either
        // way without reaching for an accent.
        color: control.checked ? Colors.base00 : Colors.base04

        Behavior on x {
            NumberAnimation {
                duration: StyleTokens.easeDurationFast
                easing.type: StyleTokens.easeStandard
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: StyleTokens.easeDurationFast
                easing.type: StyleTokens.easeSymmetric
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: control.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (control.interactive)
                control.toggled();
        }
    }
}
