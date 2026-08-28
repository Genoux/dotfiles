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

    // A bar popover grows upward, so a content-fit segmented body would move
    // the segments themselves on every switch. Sized to the taller segment:
    // Record carries an audio row under its tiles, Shot does not.
    readonly property int bodyHeight: StylePopover.tileHeight
        + StylePopover.listRowHeight
        + StyleTokens.space8
}
