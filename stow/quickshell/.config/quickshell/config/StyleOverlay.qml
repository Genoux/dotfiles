pragma Singleton

import Quickshell

import QtQuick
import qs

Singleton {
    readonly property color backdrop: "#191818"
    readonly property real backdropOpacity: 0
    // The one glass every floating surface shares: island, bar popovers, launcher,
    // notifications, capture card and OSD. Palette-tinted, so it follows the
    // wallpaper rather than sitting on a fixed grey. Its alpha must stay above
    // the quickshell-popover rule's ignore_alpha (0.5, windowrules.lua), or the
    // compositor stops blurring behind it.
    readonly property color surface: StyleTokens.surfaceAlpha(Colors.base00, 0.62)
    // Rules and edges *inside* a surface — separators, input outlines, the
    // selected-row border.
    readonly property color borderSubtle: StyleTokens.alphaHairline
    // Kept under the compositor's blur threshold. Hyprland blurs per pixel,
    // all or nothing, wherever alpha exceeds ignore_alpha (0.5). The threshold
    // sits just under the surface's own alpha, so a rounded corner's thin,
    // antialiased edge shows the real background like the pixels beside it,
    // rather than a sliver of blurred backdrop standing out as a bright rim; and
    // a shadow below it is never blurred into a halo.
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.2)
    readonly property int shadowOffset: 4
    readonly property int shadowBlur: 12
    // Odd and at least blur * 2 + 1, or DropShadow bands visibly.
    readonly property int shadowSamples: shadowBlur * 2 + 1
    readonly property real hiddenScale: 0.98
    readonly property int showDuration: StyleTokens.motionEnterDuration
    readonly property int hideDuration: StyleTokens.motionExitDuration
}
