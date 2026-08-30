pragma Singleton

import Quickshell

import QtQuick

Singleton {
    // Preview card. A tile, not a banner: at notification width the thumbnail
    // stretched across the corner, and a capture is a picture, not text. The
    // window is right-anchored, so the card's right edge still lands on the
    // notification stack's inset — only the left edge moves in.
    readonly property int cardWidth: 180
    // 4:3, not 1:1. A square crops a 16:9 capture down to its middle third and
    // stands too tall in the corner; this keeps the tile short and still reads
    // as a picture.
    readonly property int thumbnailHeight: 135
    // The thumbnail is the whole card: no filename band, no action strip. The
    // actions live over the image and only appear on hover.
    readonly property int cardHeight: thumbnailHeight
    readonly property int previewTimeout: 8000
    // Long enough to read the check as confirmation, short enough that the card
    // is not still sitting there once you have believed it.
    readonly property int copiedHold: 700
    // Stronger than the shared surface hairline on purpose. Every other panel
    // is a translucent dark surface, so 1-2% white reads against it. This card
    // is a photograph edge to edge, and a 2% stroke has nothing to sit against
    // — it vanishes into whatever was on screen. Still one pixel, per the
    // border rule: the alpha carries it, not the width.
    readonly property color border: Qt.rgba(1, 1, 1, 0.08)
    readonly property int posterWidth: cardWidth

    // Icons over a photograph need the photograph dimmed to stay legible. The
    // controls themselves are ordinary PillButtons on top of that.
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.55)
    readonly property int actionPadding: StyleTokens.space10
    // Same reason the border is stronger here: the shared hover tint is 3%
    // white, which reads against a translucent panel and disappears against a
    // photograph under a scrim. Local to this card so panel hovers stay quiet.
    readonly property color actionHover: Qt.rgba(1, 1, 1, 0.16)
    // Dismiss acts on the card, not on the capture, so it sits a size below the
    // three actions rather than competing with them.
    readonly property int dismissPadding: StyleTokens.space6

    // Both segments hold one tile row, so the band needs no slack for either.
    // Bottom padding only: the segment band above already closes on
    // segmentBandPaddingBottom, and adding air on this side of the same seam
    // would make the gap under the tabs twice the padding beside the tiles.
    readonly property int bodyHeight: StylePopover.tileHeight
        + StylePopover.contentPaddingV
}
