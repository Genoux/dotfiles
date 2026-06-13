import QtQuick
import qs
import qs.config

Rectangle {
    id: root

    default property alias content: contentContainer.data

    readonly property real borderOpacity: 0.07
    readonly property real chromeInset: border.width + Style.mediaPadding

    implicitHeight: Style.mediaHeight
    height: implicitHeight
    border.width: 1
    border.color: Qt.rgba(Colors.base04.r, Colors.base04.g, Colors.base04.b, borderOpacity)
    radius: Style.radiusMd
    color: Style.transparent

    Item {
        id: contentContainer

        anchors.fill: parent
        anchors.margins: root.chromeInset
    }
}
