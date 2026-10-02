pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property color backdrop: "#191818"
    readonly property real backdropOpacity: 0
    // The one glass every floating surface shares: bar popovers, the island and
    // the launcher. Dense enough that a bright window behind does not wash the
    // text out, light enough to stay see-through.
    readonly property color surface: Qt.rgba(8 / 255, 8 / 255, 8 / 255, 0.4)
    // Rules and edges *inside* a surface — separators, input outlines, the
    // selected-row border.
    readonly property color borderSubtle: StyleTokens.alphaHairline
    // Kept under the compositor's blur threshold: Hyprland's layer rule for the
    // quickshell-popover namespace blurs wherever alpha exceeds ignore_alpha (0.3,
    // in windowrules.lua), and a blurred region has a hard, unantialiased edge.
    // The threshold sits above the antialiased rim of every surface, so the blur
    // stops just inside it and the rim stays smooth; a shadow below the threshold
    // is never blurred into a halo.
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.14)
    readonly property real hiddenScale: 0.98
    readonly property int showDuration: StyleTokens.motionEnterDuration
    readonly property int hideDuration: StyleTokens.motionExitDuration
}
