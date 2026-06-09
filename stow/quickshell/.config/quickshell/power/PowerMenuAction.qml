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

    width: Style.powerMenuItemWidth
    height: Style.powerMenuItemHeight
    radius: Style.radiusMd
    color: selected ? Style.powerMenuSelectedBg : Style.transparent
    border.width: selected ? 1 : 0
    border.color: Style.overlayBorderSubtle

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Style.powerMenuItemSpacing

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Style.powerMenuIconSize
            Layout.preferredHeight: Style.powerMenuIconSize
            width: Style.powerMenuIconSize
            height: Style.powerMenuIconSize

            IconImage {
                id: iconSource

                anchors.fill: parent
                source: Quickshell.iconPath(root.icon)
                visible: false
            }

            ColorOverlay {
                anchors.fill: parent
                source: iconSource
                color: Style.powerMenuText
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            color: Style.powerMenuText
            font.family: Style.fontSans
            font.pixelSize: Style.powerMenuLabelSize
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
