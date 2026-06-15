import QtQuick
import qs
import qs.config

Rectangle {
    id: root

    default property alias content: contentContainer.data

    readonly property int contentWidth: contentContainer.implicitWidth
    readonly property int contentHeight: contentContainer.implicitHeight

    implicitWidth: contentWidth + StyleGroup.chromeInset * 2
    implicitHeight: contentHeight + StyleGroup.chromeInset * 2
    width: implicitWidth
    height: implicitHeight
    border.width: StyleGroup.borderWidth
    border.color: Qt.rgba(
        Colors.base04.r,
        Colors.base04.g,
        Colors.base04.b,
        StyleGroup.borderOpacity
    )
    radius: StyleTokens.radiusMd
    color: StyleTokens.transparent

    Item {
        id: contentContainer

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: StyleGroup.chromeInset
        anchors.leftMargin: StyleGroup.chromeInset
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }
}
