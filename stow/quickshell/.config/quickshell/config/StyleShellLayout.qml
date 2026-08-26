pragma Singleton

import Quickshell

import QtQuick

Singleton {
    // Keep the OSD one generous offset above the bar rather than touching it.
    readonly property int osdBottomMargin: StyleBar.height + StyleBar.margin + StyleTokens.space16 * 2
    // Pull notifications toward the bar by one compact spacing step.
    readonly property int notificationBottomMargin: StyleBar.height + StyleBar.margin - StyleTokens.space6
    // Align notification chrome with the visible edge inside the bar margin.
    readonly property int notificationRightMargin: StyleBar.margin - StyleTokens.space2
}
