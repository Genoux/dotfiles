import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import qs.config

ClippingRectangle {
    id: card

    // A host that outlives its own closing (a bar popover keeps its content)
    // drops the image while hidden.
    property bool shown: true
    // Which of the two layers is in front. A new wallpaper decodes into the one
    // behind, out of sight, then comes forward and fades in over the old one,
    // so a swap never shows an empty card.
    property int front: 0

    // A new wallpaper has been decoded into the card.
    signal refreshed()

    // Uncached, so clearing the source and setting it again decodes afresh.
    function decode(layer) {
        layer.source = "";
        layer.source = StyleTokens.wallpaperPath;
    }

    function showWallpaper() {
        const layer = layerRepeater.itemAt(front);
        layer.opacity = 1;
        decode(layer);
    }

    function swapWallpaper() {
        const incoming = layerRepeater.itemAt(1 - front);
        incoming.opacity = 0;
        decode(incoming);
    }

    function release() {
        for (let index = 0; index < layerRepeater.count; index++)
            layerRepeater.itemAt(index).source = "";
    }

    radius: StyleIsland.heroRadius
    color: StyleTokens.alphaLight
    onShownChanged: shown ? showWallpaper() : release()
    Component.onCompleted: {
        if (shown)
            showWallpaper();
    }

    // A swap writes the new wallpaper over this same path, so the card watches
    // it rather than its host knowing when a swap ran. Not preloaded: only the
    // change matters, never the bytes.
    FileView {
        path: StyleTokens.wallpaperPath
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: settle.restart()
    }

    // The write lands in pieces; decoding on the first change would read a
    // half-written image.
    Timer {
        id: settle

        interval: StyleIsland.wallpaperSettleDelay
        onTriggered: {
            if (card.shown)
                card.swapWallpaper();
        }
    }

    // Its own stacking context, so the layers' order never lifts an image over
    // what the host places on the card.
    Item {
        id: layers

        anchors.fill: parent

        Repeater {
            id: layerRepeater

            model: 2

            Image {
                id: layer

                required property int index

                anchors.fill: parent
                z: index === card.front ? 1 : 0
                sourceSize.width: StyleIsland.heroImageWidth
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                onStatusChanged: {
                    if (status !== Image.Ready || index === card.front)
                        return;

                    card.front = index;
                    fadeIn.restart();
                }

                NumberAnimation {
                    id: fadeIn

                    target: layer
                    property: "opacity"
                    to: 1
                    duration: StyleIsland.wallpaperCrossfadeDuration
                    easing.type: StyleTokens.easeFade
                    onFinished: {
                        layerRepeater.itemAt(1 - layer.index).source = "";
                        card.refreshed();
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: StyleIsland.heroScrimStart; color: StyleTokens.transparent }
            GradientStop { position: 1; color: StyleIsland.heroScrim }
        }
    }
}
