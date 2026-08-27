import QtQuick
import qs
import qs.components
import qs.config
import qs.services

// One selectable device in the output or input list.
//
// Not a PopoverAction: that component's row mode renders a label only — its icon
// lives in the stacked tile branch — and a selection gutter has to be reserved
// for every row in the group, not just the chosen one, or the labels sit at two
// different insets. Both are group facts PopoverAction has no notion of.
Rectangle {
    id: row

    required property var node
    required property bool selected

    signal activated()

    implicitHeight: StylePopover.rowHeight
    height: implicitHeight
    radius: StyleTokens.radiusSm
    color: area.containsMouse ? StyleTokens.alphaLight : StyleTokens.transparent

    Behavior on color {
        ColorAnimation {
            duration: StyleTokens.easeDurationFast
            easing.type: StyleTokens.easeStandard
        }
    }

    // The gutter is always reserved so every label starts at the same inset; only
    // the fill inside it says which device is current.
    Item {
        id: marker

        anchors.left: parent.left
        anchors.leftMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
        anchors.verticalCenter: parent.verticalCenter
        width: StyleTokens.space6
        height: width

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            color: row.selected ? Colors.base05 : StyleTokens.transparent

            Behavior on color {
                ColorAnimation {
                    duration: StyleTokens.easeDurationFast
                    easing.type: StyleTokens.easeSymmetric
                }
            }
        }
    }

    Text {
        anchors.left: marker.right
        anchors.leftMargin: StyleTokens.space10
        anchors.right: parent.right
        anchors.rightMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
        anchors.verticalCenter: parent.verticalCenter
        text: AudioState.label(row.node)
        color: row.selected ? Colors.base05 : Colors.base04
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeSm
        font.weight: row.selected ? Font.DemiBold : Font.Normal
        elide: Text.ElideRight
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
    }
}
