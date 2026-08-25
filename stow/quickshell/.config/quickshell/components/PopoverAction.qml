import QtQuick
import qs
import qs.config

Rectangle {
    id: action

    required property string label
    property string iconName: ""
    property string badgeIconName: ""
    property bool stacked: false
    property bool separator: false
    property bool actionEnabled: true

    // Metrics default to the bar-panel row; a context menu overrides them for
    // tighter rows and narrower gutters.
    property int rowHeight: StylePopover.rowHeight
    property int paddingH: StylePopover.contentPaddingH

    readonly property bool hasIcon: iconName.length > 0
    readonly property var resolvedSource: hasIcon ? IconRegistry.source(iconName) : ""
    readonly property var badgeSource: badgeIconName.length > 0 ? IconRegistry.source(badgeIconName) : ""

    signal activated()

    implicitWidth: {
        if (separator)
            return 0;
        if (stacked)
            return StylePopover.tileWidth;
        return labelText.implicitWidth + paddingH * 2;
    }
    implicitHeight: {
        if (separator)
            return StylePopover.separatorHeight;
        if (stacked)
            return StylePopover.tileHeight;
        return rowHeight;
    }
    radius: separator ? 0 : StyleTokens.radiusSm
    color: separator
        ? StyleOverlay.borderSubtle
        : (mouseArea.containsMouse ? StyleTokens.alphaLight : StyleTokens.transparent)

    Column {
        id: tileColumn

        visible: action.stacked && !action.separator
        anchors.centerIn: parent
        spacing: 4
        width: parent.width - StylePopover.tileCaptionPadding * 2

        ThemedIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: action.hasIcon
            source: action.resolvedSource
            size: StylePopover.tileIconSize

            ThemedIcon {
                visible: action.badgeIconName.length > 0
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -3
                anchors.bottomMargin: -3
                source: action.badgeSource
                size: StylePopover.tileBadgeSize
            }
        }

        Text {
            width: parent.width
            text: action.label
            color: Colors.base05
            opacity: action.actionEnabled ? 1.0 : 0.4
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeXs
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    Text {
        id: labelText

        visible: !action.separator && !action.stacked
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
