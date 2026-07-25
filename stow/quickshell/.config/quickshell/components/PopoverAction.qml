import QtQuick
import qs
import qs.config

Rectangle {
    id: action

    required property string label
    property bool separator: false
    property bool actionEnabled: true

    signal activated()

    implicitWidth: StylePopover.panelWidth
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
        anchors.leftMargin: StylePopover.contentPaddingH
        anchors.right: parent.right
        anchors.rightMargin: StylePopover.contentPaddingH
        anchors.verticalCenter: parent.verticalCenter
        text: action.label
        color: Colors.base05
        opacity: action.actionEnabled ? 1.0 : 0.4
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeSm
        elide: Text.ElideRight
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        visible: !action.separator && action.actionEnabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: action.activated()
    }
}
