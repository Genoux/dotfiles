import QtQuick
import qs
import qs.config

// Signal strength as a ramp of ascending bars. Same idea as the volume OSD's
// step bar: filled rungs against dimmed ones, drawn rather than themed, so the
// mark follows the wallpaper palette instead of an icon theme's own colours.
Row {
    id: root

    property int filled: 0
    property int count: StyleControl.signalBarCount

    readonly property int tallest: StyleControl.signalBarBase + StyleControl.signalBarStep * (count - 1)

    spacing: StyleControl.signalBarSpacing
    // Align on the baseline so the ramp climbs away from a common floor.
    layoutDirection: Qt.LeftToRight

    Repeater {
        model: root.count

        Item {
            required property int index

            width: StyleControl.signalBarWidth
            height: root.tallest

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: StyleControl.signalBarBase + StyleControl.signalBarStep * parent.index
                radius: StyleTokens.radiusXs
                color: parent.index < root.filled ? Colors.base05 : Colors.base04
                opacity: parent.index < root.filled ? 1 : StyleTokens.opacityDisabled

                Behavior on color {
                    ColorAnimation {
                        duration: StyleTokens.easeDurationFast
                        easing.type: StyleTokens.easeSymmetric
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: StyleTokens.easeDurationFast
                        easing.type: StyleTokens.easeSymmetric
                    }
                }
            }
        }
    }
}
