pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int width: 360
    readonly property int padding: StyleTokens.space10
    readonly property int gap: StyleTokens.space2
    readonly property int iconSize: 42
    readonly property int maxVisible: 10
    readonly property int timeout: 5000
    readonly property int showDuration: StyleTokens.easeDurationFast
    readonly property int hideDuration: StyleTokens.easeDurationFast
    readonly property real surfaceAlpha: 0.54
    readonly property color surface: Qt.rgba(8 / 255, 8 / 255, 8 / 255, surfaceAlpha)
    readonly property color border: StyleTokens.alphaHairline
}
