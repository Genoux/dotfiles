import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell.Widgets
import qs
import qs.config

// Renders Freedesktop theme icons and the occasional color emoji. First-party
// shell symbols resolve from MacTahoe; application artwork remains theme-owned.
Item {
    id: icon

    property var source: ""
    property color tint: Colors.base05
    property int size: StyleControl.iconSize
    property bool colored: false

    readonly property string sourceString: String(source ?? "")
    readonly property bool emoji: sourceString.startsWith("emoji:")
    readonly property string emojiGlyph: emoji ? sourceString.slice(6) : ""
    readonly property bool symbolic: sourceString.includes("-symbolic")
        || sourceString.includes("/symbolic/")
    readonly property bool hasSource: String(source).length > 0
    // Keep application artwork full-size while giving first-party symbolic
    // assets the optical inset used throughout the shell.
    readonly property real baseScale: symbolic ? StyleControl.symbolicIconVisualScale : 1
    readonly property int drawSize: Math.round(size * baseScale)

    implicitWidth: size
    implicitHeight: size

    Item {
        anchors.centerIn: parent
        width: icon.drawSize
        height: icon.drawSize

        IconImage {
            id: themedImage

            anchors.fill: parent
            visible: !icon.emoji && icon.hasSource
            source: visible ? icon.source : ""
        }

        ColorOverlay {
            anchors.fill: parent
            visible: themedImage.visible && icon.symbolic && !icon.colored
            source: themedImage
            color: icon.tint
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
