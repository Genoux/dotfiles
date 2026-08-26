pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property color backdrop: "#191818"
    readonly property real backdropOpacity: 0
    readonly property color surface: Qt.rgba(8 / 255, 8 / 255, 8 / 255, 0.3)
    // Outline around a floating panel's own surface. Fainter than borderSubtle:
    // it traces the full perimeter against a blurred backdrop, so it reads far
    // brighter than the same value does as a short rule inside a panel.
    readonly property color surfaceBorder: Qt.rgba(1, 1, 1, 0.01)
    // Rules and edges *inside* a surface — separators, input outlines, the
    // selected-row border.
    readonly property color borderSubtle: StyleTokens.alphaHairline
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.2)
    readonly property real hiddenScale: 0.98
    readonly property int showDuration: StyleTokens.easeDurationInstant
    readonly property int hideDuration: StyleTokens.easeDurationInstant
}
