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
    readonly property int posterWidth: cardWidth

    // Icons over a photograph need the photograph dimmed to stay legible. The
    // controls themselves are ordinary PillButtons on top of that.
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.55)
    readonly property int actionPadding: StyleTokens.space10

    // Both segments hold one tile row, so the band needs no slack for either.
    // It carries contentPaddingV above and below, the same air a list column
    // gives its rows, which lands the last content the same distance from the
    // panel edge as every other popover.
    readonly property int bodyHeight: StylePopover.tileHeight
        + StylePopover.contentPaddingV * 2
}
