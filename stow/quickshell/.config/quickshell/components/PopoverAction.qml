import QtQuick
import qs
import qs.config

Rectangle {
    id: action

    required property string label
    property bool separator: false

    signal activated()

    implicitWidth: StylePopover.minWidth
    implicitHeight: separator ? StylePopover.separatorHeight : StylePopover.rowHeight
    width: implicitWidth
    height: implicitHeight
    radius: separator ? 0 : StyleTokens.radiusSm
    color: separator
        ? StyleOverlay.borderSubtle
        : (mouseArea.containsMouse ? StyleTokens.alphaLight : StyleTokens.transparent)

    Text {
        visible: !action.separator
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: action.label
        color: Colors.base05
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeSm
        elide: Text.ElideRight
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        visible: !action.separator
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: action.activated()
    }
}
