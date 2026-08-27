import QtQuick
import qs
import qs.config

// Chooses which subject a panel is showing, for a popover that covers several
// and would otherwise stack them into one long scroll.
//
// Not a row of PillButtons: the segments share one recessed track so they read as
// a single control with a current position rather than three separate toggles.
// Only the selected segment carries a fill, per the Quiet Chrome Rule.
Item {
    id: control

    property var labels: []
    // Controlled, not self-managing: the owner holds the current index and this
    // only asks for a new one. Assigning currentIndex from inside would overwrite
    // the owner's binding on first click, and every later programmatic change —
    // resetting the tab when the panel closes, say — would move the content while
    // leaving the segments showing the stale one.
    property int currentIndex: 0

    signal segmentSelected(int index)

    implicitHeight: StylePopover.segmentBarHeight
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: StyleTokens.radiusSm
        color: StyleTokens.alphaHairline
        border.width: StyleTokens.borderWidth
        border.color: StyleOverlay.borderSubtle
    }

    Row {
        anchors.fill: parent

        Repeater {
            model: control.labels

            Rectangle {
                id: segment

                required property int index
                required property var modelData

                readonly property bool selected: segment.index === control.currentIndex

                width: control.width / Math.max(1, control.labels.length)
                height: control.height
                radius: StyleTokens.radiusSm
                color: {
                    if (segment.selected)
                        return StyleTokens.alphaLight
                    return area.containsMouse ? StyleTokens.alphaHairline : StyleTokens.transparent
                }

                Behavior on color {
                    ColorAnimation {
                        duration: StyleTokens.easeDurationFast
                        easing.type: StyleTokens.easeSymmetric
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: segment.modelData
                    color: segment.selected ? Colors.base05 : Colors.base04
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeSm
                    font.weight: segment.selected ? Font.DemiBold : Font.Normal
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
