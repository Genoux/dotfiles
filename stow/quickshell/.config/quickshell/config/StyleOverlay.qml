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
    // Kept under the compositor's blur threshold: Hyprland's layer rules for the
    // quickshell namespaces blur wherever alpha exceeds ignore_alpha (0.1, in
    // windowrules.lua). A shadow that crosses it blurs a halo around the surface,
    // which bleeds a light window behind into a pale, pixelated outline. The
    // shadow's alpha peaks at half its colour's at the surface edge, so 0.14
    // stays below 0.1 everywhere outside it.
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.14)
    readonly property real hiddenScale: 0.98
    readonly property int showDuration: StyleTokens.motionEnterDuration
    readonly property int hideDuration: StyleTokens.motionExitDuration
}
