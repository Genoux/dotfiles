import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.config

Rectangle {
    id: root

    required property string label
    required property string icon
    property bool selected: false

    signal triggered()
    signal hovered()

    width: StylePowerMenu.itemWidth
    height: StylePowerMenu.itemHeight
    radius: StyleTokens.radiusMd
    color: selected ? StylePowerMenu.selectedBg : StyleTokens.transparent
    border.width: selected ? 1 : 0
    border.color: StyleOverlay.borderSubtle

    ColumnLayout {
        anchors.centerIn: parent
        spacing: StylePowerMenu.itemSpacing

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: StylePowerMenu.iconSize
            Layout.preferredHeight: StylePowerMenu.iconSize
            width: StylePowerMenu.iconSize
            height: StylePowerMenu.iconSize

            IconImage {
                id: iconSource

                anchors.fill: parent
                source: Quickshell.iconPath(root.icon)
                visible: false
            }

            ColorOverlay {
                anchors.fill: parent
                source: iconSource
                color: StylePowerMenu.text
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            color: StylePowerMenu.text
            font.family: StyleTokens.fontSans
            font.pixelSize: StylePowerMenu.labelSize
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.triggered()
    }
}
