import QtQuick
import qs.config

Row {
    id: root

    property int steps: StyleOsd.stepCount
    property real volume: 0
    property bool muted: false

    spacing: StyleOsd.stepSpacing

    Repeater {
        model: root.steps

        Rectangle {
            required property int index

            width: StyleOsd.stepWidth
            height: StyleOsd.stepHeight
            radius: StyleTokens.radiusXs

            readonly property real threshold: ((index + 1) / root.steps) - 0.001
            readonly property bool filled: !root.muted && root.volume > threshold

            color: filled ? StyleOsd.stepFilled : StyleOsd.stepEmpty

            Behavior on color {
                ColorAnimation {
                    duration: StyleTokens.easeDurationFast
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }
}
