pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int rowSpacing: StyleTokens.space1
    // Even, so the glyph centres on a whole pixel inside the 24px button box.
    readonly property int iconSize: StyleControl.iconSize - StyleTokens.space2
}
