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
    property bool colored: false

    readonly property string sourceString: String(source ?? "")
    readonly property bool materialSymbol: sourceString.startsWith("material-symbols:")
    readonly property string materialGlyph: materialSymbol ? sourceString.slice(17) : ""
    readonly property bool emoji: sourceString.startsWith("emoji:")
    readonly property string emojiGlyph: emoji ? sourceString.slice(6) : ""
    readonly property bool bundled: IconRegistry.isBarIcon(source)
    readonly property bool hasSource: String(source).length > 0
    // Bundled assets are authored to fill their canvas and need the shared
    // inset. Theme icons already include their own padding, so opticalScale()
    // alone normalizes their visible bounds inside the requested slot.
    readonly property real baseScale: bundled ? StyleControl.iconVisualScale : 1
    readonly property int drawSize: Math.round(size * baseScale * IconRegistry.opticalScale(source))

    implicitWidth: size
    implicitHeight: size

    Item {
        anchors.centerIn: parent
        width: icon.drawSize
        height: icon.drawSize

        Image {
            id: bundledImage

            anchors.fill: parent
            visible: icon.bundled && icon.hasSource
            source: visible ? icon.source : ""
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(icon.drawSize, icon.drawSize)
        }

        ColorOverlay {
            anchors.fill: parent
            visible: bundledImage.visible && !icon.colored
            source: bundledImage
            color: icon.tint
        }

        IconImage {
            anchors.fill: parent
            visible: !icon.bundled && !icon.materialSymbol && !icon.emoji && icon.hasSource
            source: visible ? icon.source : ""
        }

        Text {
            anchors.fill: parent
            visible: icon.materialSymbol
            text: icon.materialGlyph
            color: icon.tint
            font.family: "Material Symbols Rounded"
            font.pixelSize: icon.drawSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            anchors.fill: parent
            visible: icon.emoji
            text: icon.emojiGlyph
            font.family: "Noto Color Emoji"
            font.pixelSize: icon.drawSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
