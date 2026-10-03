import Quickshell
import Quickshell.Widgets
import QtQuick
import qs
import qs.config
import qs.components

// A notification's picture: the image it carries, or else its app's icon. In a
// glass well by default; `bare` drops the well, the way the island shows a
// logo, and rounds an image into a circle.
Item {
    id: root

    property string image: ""
    property string iconName: ""
    property bool bare: false

    readonly property bool hasImage: image.length > 0
    readonly property string iconSource: Quickshell.iconPath(root.iconName || "dialog-information-symbolic", "dialog-information-symbolic")
    readonly property bool symbolic: iconSource.includes("-symbolic") || iconSource.includes("/symbolic/")

    ClippingRectangle {
        anchors.fill: parent
        visible: root.hasImage
        radius: root.bare ? width / 2 : StyleTokens.radiusMd
        color: StyleTokens.transparent

        Image {
            anchors.fill: parent
            source: root.image
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.width, root.height)
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.hasImage && !root.bare
        radius: StyleControl.chipRadius
        color: StyleTokens.alphaLight
    }

    ThemedIcon {
        anchors.centerIn: parent
        visible: !root.hasImage
        size: root.bare && !root.symbolic ? root.width : StyleControl.iconSizeMd
        source: root.iconSource
        tint: root.bare ? Colors.base06 : Colors.base05
    }
}
