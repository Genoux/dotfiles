import QtQuick
import qs
import qs.config

// Panel title bar: the subject on the left, one control opposite it. Children
// are placed in the trailing slot.
Item {
    id: header

    property string title: ""
    property int horizontalPadding: StylePopover.contentPaddingH
    default property alias trailing: trailingSlot.data

    implicitWidth: titleText.implicitWidth + horizontalPadding * 2 + trailingSlot.width
    implicitHeight: StylePopover.headerHeight
    height: implicitHeight

    Text {
        id: titleText

        anchors.left: parent.left
        anchors.leftMargin: header.horizontalPadding
        anchors.right: trailingSlot.left
        anchors.rightMargin: StyleTokens.space8
        anchors.verticalCenter: parent.verticalCenter
        text: header.title
        color: Colors.base05
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeLg
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Item {
        id: trailingSlot

        anchors.right: parent.right
        anchors.rightMargin: header.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
