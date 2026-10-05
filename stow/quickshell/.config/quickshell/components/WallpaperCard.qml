import QtQuick
import Quickshell.Widgets
import qs.config

ClippingRectangle {
    id: card

    // A host that outlives its own closing (a bar popover keeps its content)
    // drops the image while hidden.
    property bool shown: true

    radius: StyleIsland.heroRadius
    color: StyleTokens.alphaLight

    // Uncached: theme.sh rewrites this one path, and the image is decoded afresh
    // each time the card is shown, which picks up a new wallpaper without
    // watching the file.
    Image {
        anchors.fill: parent
        source: card.shown ? StyleTokens.wallpaperPath : ""
        sourceSize.width: StyleIsland.heroImageWidth
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: StyleIsland.heroScrimStart; color: StyleTokens.transparent }
            GradientStop { position: 1; color: StyleIsland.heroScrim }
        }
    }
}
