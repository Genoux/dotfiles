import QtQuick
import qs
import qs.components
import qs.config
import qs.services

// One selectable device in the output or input list.
//
// Not a PopoverAction: that renders a label only, and this row ends in a check
// for the current device, which PopoverAction has no notion of.
Rectangle {
    id: row

    required property var node
    required property bool selected

    signal activated()

    implicitHeight: StylePopover.rowHeight
    height: implicitHeight
    radius: StylePopover.listRowRadius
    // The current device keeps its own fill: it outlasts the pointer, so it is
    // state rather than hover and the run's indicator cannot express it.
    color: row.selected ? StyleTokens.alphaLight : StyleTokens.transparent

    // The list's travelling indicator paints the hover fill for the whole run.
    readonly property bool hovered: area.containsMouse && !row.selected

    Behavior on color {
        ColorAnimation {
            duration: StyleTokens.motionFeedbackDuration
            easing.type: StyleTokens.easeFade
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: StylePopover.contentPaddingH - row.x
        anchors.right: check.left
        anchors.rightMargin: StyleTokens.space8
        anchors.verticalCenter: parent.verticalCenter
        text: AudioState.label(row.node)
        color: row.selected ? Colors.base06 : Colors.base04
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeSm
        font.weight: row.selected ? Font.DemiBold : Font.Normal
        elide: Text.ElideRight

        Behavior on color {
            ColorAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeFade
            }
        }
    }

    // The current device says so at the row's end, where the eye finishes a
    // line, rather than in a gutter every other row has to keep empty.
    ThemedIcon {
        id: check

        anchors.right: parent.right
        anchors.rightMargin: StylePopover.contentPaddingH - row.x
        anchors.verticalCenter: parent.verticalCenter
        size: StyleControl.iconSizeSm
        source: IconRegistry.themeIcon("object-select-symbolic")
        tint: Colors.base05
        opacity: row.selected ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
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
        onClicked: row.activated()
    }
}
