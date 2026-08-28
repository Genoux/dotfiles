pragma Singleton

import Quickshell

import QtQuick

Singleton {
    // Preview card. Width borrows the notification width on purpose: the card
    // shares the bottom-right column with the notification stack, and a
    // different width would read as two misaligned surfaces rather than one.
    readonly property int cardWidth: StyleNotification.width
    readonly property int thumbnailHeight: 160
    // The thumbnail is the whole card: no filename band, no action strip. The
    // actions live over the image and only appear on hover.
    readonly property int cardHeight: thumbnailHeight
    readonly property int previewTimeout: 8000
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

    // Both segments hold one tile row, so the band needs no slack for either.
    // Bottom padding only: the segment band above already closes on
    // segmentBandPaddingBottom, and adding air on this side of the same seam
    // would make the gap under the tabs twice the padding beside the tiles.
    readonly property int bodyHeight: StylePopover.tileHeight
        + StylePopover.contentPaddingV
}
