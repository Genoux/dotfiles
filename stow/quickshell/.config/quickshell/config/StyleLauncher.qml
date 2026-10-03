pragma Singleton

import Quickshell

import QtQuick
import qs

Singleton {
    // The launcher looks the same wherever it opens: in the island, or centred on
    // the screen. So its metrics are the island's own -- its fills' inset and
    // gap, and corners concentric with its surface. Only the width differs: the
    // island page is as wide as the dock, the window is free to be roomier.
    readonly property int width: 600
    readonly property int padding: StyleIsland.fillInset
    readonly property int spacing: StyleIsland.fillInset
    readonly property int surfaceRadius: StyleTokens.radiusXl
    readonly property int rowRadius: StylePopover.listRowRadius
    readonly property int searchHeight: 40
    readonly property int resultHeight: 40
    readonly property int emptyHeight: 200
    readonly property int listMaxHeight: 300
    readonly property int iconSize: 24
    readonly property int searchIconSize: 16
    readonly property int maxResults: 100
    readonly property color text: Colors.base05
    readonly property color selection: StyleTokens.surfaceAlpha(text, 0.2)
    readonly property color placeholder: Colors.base04
}
