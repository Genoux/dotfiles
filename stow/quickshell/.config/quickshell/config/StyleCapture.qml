pragma Singleton

import Quickshell

import QtQuick

Singleton {
    // Preview card. Width borrows the notification width on purpose: the card
    // shares the bottom-right column with the notification stack, and a
    // different width would read as two misaligned surfaces rather than one.
    readonly property int cardWidth: StyleNotification.width
    readonly property int thumbnailHeight: 160
    readonly property int cardHeight: thumbnailHeight
        + StylePopover.listRowHeight
        + StylePopover.rowHeight
        + StyleNotification.padding * 2
    readonly property int previewTimeout: 8000
    readonly property int posterWidth: cardWidth

    // A bar popover grows upward, so a content-fit segmented body would move
    // the segments themselves on every switch. Sized to the taller segment:
    // Record carries an audio row under its tiles, Shot does not.
    readonly property int bodyHeight: StylePopover.tileHeight
        + StylePopover.listRowHeight
        + StyleTokens.space8
}
