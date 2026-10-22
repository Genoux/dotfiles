import QtQuick
import qs
import qs.config

Rectangle {
    id: action

    required property string label
    property bool separator: false
    property bool actionEnabled: true
    // Holds the hover look while something this row opened is still showing.
    property bool pinned: false

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
            return StylePopover.separatorHeight + StylePopover.separatorGap * 2;
        return rowHeight;
    }
    radius: separator ? 0 : StylePopover.listRowRadius
    // A menu row's hover fill is painted by its list's travelling indicator.
    color: StyleTokens.transparent

    readonly property bool hovered: !separator && (pinned || mouseArea.containsMouse)

    Rectangle {
        visible: action.separator
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: StylePopover.separatorHeight
        color: StyleOverlay.borderSubtle
    }

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
