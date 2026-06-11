import QtQuick
import Qt5Compat.GraphicalEffects
import qs.config

Item {
    id: root

    property real revealOpacity: 1

    default property alias content: contentLayer.data

    DropShadow {
        anchors.fill: surface
        source: surface
        horizontalOffset: 6
        verticalOffset: 6
        radius: 10
        samples: 21
        color: Style.overlayShadow
        opacity: root.revealOpacity
        transparentBorder: true
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: Style.radiusMd
        color: Style.overlaySurface
        border.width: 1
        border.color: Style.overlayBorderSubtle
        opacity: root.revealOpacity
    }

    Item {
        id: contentLayer

        anchors.fill: parent
        opacity: root.revealOpacity
    }
}
