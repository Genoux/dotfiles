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

    implicitWidth: {
        if (separator)
            return 0;
        return labelText.implicitWidth + paddingH * 2;
    }
    implicitHeight: {
        if (separator)
            return StylePopover.separatorHeight;
        return rowHeight;
    }
    radius: separator ? 0 : StylePopover.listRowRadius
    // A menu row's hover fill is painted by its list's travelling indicator;
    // only the separator keeps a colour of its own.
    color: separator ? StyleOverlay.borderSubtle : StyleTokens.transparent

    readonly property bool hovered: !separator && mouseArea.containsMouse

    Text {
        id: labelText

        visible: !action.separator
        anchors.left: parent.left
        anchors.leftMargin: action.paddingH
        anchors.right: parent.right
        anchors.rightMargin: action.paddingH
        anchors.verticalCenter: parent.verticalCenter
        text: action.label
        textFormat: Text.PlainText
        color: Colors.base05
        opacity: action.actionEnabled ? 1.0 : StyleTokens.opacityDisabled
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
