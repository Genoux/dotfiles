import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell.Widgets
import qs
import qs.config

// Renders either a bundled SVG or a Freedesktop theme icon, whichever the
// source resolves to. Bundled SVGs are monochrome and get tinted to the
// current foreground; theme icons carry their own colors and are left alone.
Item {
    id: icon

    property var source: ""
    property color tint: Colors.base05
    property int size: StyleControl.iconSize

    readonly property bool bundled: IconRegistry.isBarIcon(source)
    readonly property bool hasSource: String(source).length > 0

    implicitWidth: size
    implicitHeight: size

    Image {
        id: bundledImage

        anchors.fill: parent
        visible: icon.bundled && icon.hasSource
        source: icon.source
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(icon.size, icon.size)
    }

    ColorOverlay {
        anchors.fill: parent
        visible: bundledImage.visible
        source: bundledImage
        color: icon.tint
    }

    IconImage {
        anchors.fill: parent
        visible: !icon.bundled && icon.hasSource
        source: icon.source
    }
}
