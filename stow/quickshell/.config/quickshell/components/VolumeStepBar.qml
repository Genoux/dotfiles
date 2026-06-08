import QtQuick
import qs.config

Row {
    id: root

    property int steps: Style.osdStepCount
    property real volume: 0
    property bool muted: false

    spacing: Style.osdStepSpacing

    Repeater {
        model: root.steps

        Rectangle {
            required property int index

            width: Style.osdStepWidth
            height: Style.osdStepHeight
            radius: Style.radiusXs

            readonly property real threshold: ((index + 1) / root.steps) - 0.001
            readonly property bool filled: !root.muted && root.volume > threshold

            color: filled ? Style.osdStepFilled : Style.osdStepEmpty

            Behavior on color {
                ColorAnimation {
                    duration: Style.easeDurationFast
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }
}
