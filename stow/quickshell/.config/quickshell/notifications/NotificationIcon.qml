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
    property string desktopEntry: ""
    property bool bare: false

    readonly property bool hasImage: image.length > 0
    // A name that is an app's desktop entry shows that entry's Icon=, not the
    // theme icon of the same name. Quickshell moves a sender's desktop-entry
    // hint into appIcon, so an icon name may be an entry id in disguise; only
    // exact matches count, so a stock name never borrows an app's icon.
    readonly property var namedEntry: IconRegistry.declaredEntry(desktopEntry) ?? IconRegistry.declaredEntry(iconName)
    readonly property string entryIcon: namedEntry ? Quickshell.iconPath(namedEntry.icon, true) : ""
    readonly property string iconSource: entryIcon
        || Quickshell.iconPath(root.iconName || root.desktopEntry || "dialog-information-symbolic", "dialog-information-symbolic")
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
