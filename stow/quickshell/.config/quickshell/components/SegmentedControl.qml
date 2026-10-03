import QtQuick
import qs
import qs.config

// Chooses which subject a panel is showing, for a popover that covers several
// and would otherwise stack them into one long scroll.
//
// Not a row of PillButtons: the segments share one recessed track so they read as
// a single control with a current position rather than three separate toggles.
// Only the selected segment carries a fill, per the Quiet Chrome Rule — and that
// chip travels between segments, because a shared track with a current position
// is exactly the thing a moving indicator describes.
Item {
    id: control

    property var labels: []
    property color textColor: Colors.base04
    // Controlled, not self-managing: the owner holds the current index and this
    // only asks for a new one. Assigning currentIndex from inside would overwrite
    // the owner's binding on first click, and every later programmatic change —
    // resetting the tab when the panel closes, say — would move the content while
    // leaving the segments showing the stale one.
    property int currentIndex: 0
    readonly property int segmentGap: StyleControl.segmentInset
    readonly property real segmentRadius: Math.max(0, StyleControl.segmentTrackRadius - segmentGap)

    signal segmentSelected(int index)

    implicitHeight: StyleControl.segmentHeight
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: StyleControl.segmentTrackRadius
        color: StyleTokens.alphaLight
    }

    // Shares the row's rect without being laid out by it: a Row positions every
    // child it has, so the indicator cannot live inside segmentRow itself.
    Item {
        anchors.fill: parent
        anchors.margins: control.segmentGap

        SlidingHighlight {
            // count is read so the binding re-runs once the Repeater has built
            // its segments; itemAt alone returns null on the first evaluation.
            target: segments.count > 0 ? segments.itemAt(control.currentIndex) : null
            radius: control.segmentRadius
            color: StyleControl.chipFill
        }
    }

    Row {
        id: segmentRow

        anchors.fill: parent
        anchors.margins: control.segmentGap
        spacing: control.segmentGap

        Repeater {
            id: segments

            model: control.labels

            Rectangle {
                id: segment

                required property int index
                required property var modelData

                readonly property bool selected: segment.index === control.currentIndex

                width: (segmentRow.width - segmentRow.spacing * Math.max(0, control.labels.length - 1))
                    / Math.max(1, control.labels.length)
                height: segmentRow.height
                radius: control.segmentRadius
                // The selected fill is the travelling indicator above, so this
                // paints only the hover preview of a segment you have not picked.
                color: area.containsMouse && !segment.selected
                    ? StyleTokens.alphaActive
                    : StyleTokens.transparent

                Behavior on color {
                    ColorAnimation {
                        duration: StyleTokens.motionFeedbackDuration
                        easing.type: StyleTokens.easeFade
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: segment.modelData
                    color: segment.selected ? StyleControl.chipContent : (area.containsMouse ? Colors.base05 : control.textColor)
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeSm
                    font.weight: segment.selected ? Font.DemiBold : Font.Normal

                    Behavior on color {
                        ColorAnimation {
                            duration: StyleTokens.motionFeedbackDuration
                            easing.type: StyleTokens.easeFade
                        }
                    }
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: control.segmentSelected(segment.index)
                }
            }
        }
    }
}
