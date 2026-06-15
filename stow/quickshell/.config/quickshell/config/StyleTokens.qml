pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property string fontSans: "SF Pro Text"
    readonly property string fontMono: "JetBrainsMono Nerd Font Mono"
    readonly property string fontIcon: "JetBrainsMono Nerd Font"
    readonly property string fontEmoji: "Noto Color Emoji"

    readonly property int fontSizeSm: 12
    readonly property int fontSizeXs: 10
    readonly property int fontSizeMedia: 11

    readonly property int radiusXs: 2
    readonly property int radiusSm: 4
    readonly property int radiusMd: 8

    readonly property int pollIntervalFast: 1000
    readonly property int pollIntervalNormal: 5000
    readonly property int pollIntervalSlow: 30000

    readonly property int easeDurationFast: 150
    readonly property int easeDurationNormal: 200

    readonly property color transparent: "transparent"
    readonly property color alphaLight: Qt.rgba(1, 1, 1, 0.05)

    function surfaceAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }
}
