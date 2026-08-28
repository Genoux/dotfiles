pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int width: 360
    readonly property int padding: StyleTokens.space10
    // Cards are large surfaces carrying an image or two lines of text, not list
    // rows: at the 2px it used to be they read as one continuous slab rather
    // than as separate things you can act on one at a time.
    readonly property int gap: StyleTokens.space8
    readonly property int iconSize: 42
    readonly property int maxVisible: 10
    readonly property int timeout: 5000
    readonly property int showDuration: StyleTokens.easeDurationFast
    readonly property int hideDuration: StyleTokens.easeDurationFast
    readonly property real surfaceAlpha: 0.54
    readonly property color surface: Qt.rgba(8 / 255, 8 / 255, 8 / 255, surfaceAlpha)
    readonly property color border: StyleTokens.alphaHairline

    // Room to the right of a card for the drag-to-dismiss gesture. A layer
    // surface cannot paint outside itself, so its window is widened by this and
    // pulled the same distance past the output edge with a negative margin —
    // the card still rests at the same inset, but now has somewhere to go. The
    // window's input mask keeps the runway from swallowing desktop clicks.
    //
    // One card width: anything less and the drag stops with the card still
    // half on screen, which reads as hitting a wall rather than throwing it
    // away. At this length the gesture can carry it entirely past the edge.
    readonly property int dragRunway: width
    // Past this a release dismisses; short of it the card springs back.
    readonly property int dragThreshold: 72
}
