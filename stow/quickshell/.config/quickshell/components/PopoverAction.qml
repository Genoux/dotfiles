import QtQuick
import qs
import qs.config

Rectangle {
    id: action

    required property string label
    property bool separator: false
    property bool actionEnabled: true

    // Metrics default to the bar-panel row; a context menu overrides them for
    // tighter rows and narrower gutters.
    property int rowHeight: StylePopover.rowHeight
    property int paddingH: StylePopover.contentPaddingH

    signal activated()

    // Natural content width, so a menu that sizes to its widest entry can read
    // it off the column. Callers wanting a fixed slab set `width` explicitly.
    implicitWidth: separator ? 0 : labelText.implicitWidth + paddingH * 2
    implicitHeight: separator ? StylePopover.separatorHeight : rowHeight
    radius: separator ? 0 : StyleTokens.radiusSm
    color: separator
        ? StyleOverlay.borderSubtle
        : (mouseArea.containsMouse ? StyleTokens.alphaLight : StyleTokens.transparent)

    Text {
        id: labelText

        visible: !action.separator
        anchors.left: parent.left
        anchors.leftMargin: action.paddingH
        anchors.right: parent.right
        anchors.rightMargin: action.paddingH
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
