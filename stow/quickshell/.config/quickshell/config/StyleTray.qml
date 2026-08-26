pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int rowSpacing: StyleTokens.space1
    // Trim the tray icon box by one pixel to match symbolic icon optics.
    readonly property int iconSize: StyleControl.iconSize - StyleTokens.space1
    readonly property int buttonPaddingHorizontal: StyleTokens.space4
    readonly property int buttonPaddingVertical: StyleTokens.space3
}
