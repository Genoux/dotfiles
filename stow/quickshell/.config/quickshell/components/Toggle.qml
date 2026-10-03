import QtQuick
import qs
import qs.config

// A real switch: the knob's position states the value, so the control says what
// it IS rather than needing a word to say it. Replaces the "On"/"Off" PillButton
// in panel headers, where that pill read as a button you press to get somewhere
// rather than a state you are looking at.
//
// Monochrome on purpose. The shell carries state in weight and fill rather than
// accent colour, so "on" is the selected chip and "off" is a faint glass track.
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
    color: control.checked ? StyleControl.chipFill : StyleTokens.alphaActive
    opacity: control.interactive ? 1 : StyleTokens.opacityDisabled

    Behavior on color {
        ColorAnimation {
            duration: StyleTokens.motionFeedbackDuration
            easing.type: StyleTokens.easeFade
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
        color: control.checked ? StyleControl.chipContent : Colors.base05

        Behavior on x {
            NumberAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeStandard
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeFade
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
