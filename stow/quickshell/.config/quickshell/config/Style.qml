pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property string fontSans: "SF Pro Text"
    readonly property string fontMono: "JetBrainsMono Nerd Font Mono"
    readonly property string fontIcon: "JetBrainsMono Nerd Font"

    readonly property int barHeight: 34
    readonly property int barMargin: 8
    readonly property int pillHeight: 22
    readonly property int fontSizeSm: 12
    readonly property int fontSizeXs: 10
    readonly property int iconSize: 14
    readonly property int iconSizeSm: 13
    readonly property int iconSizeXs: 12
    readonly property int radiusSm: 4
    readonly property int radiusMd: 8

    readonly property color transparent: "transparent"
    readonly property color alphaLight: Qt.rgba(1, 1, 1, 0.05)
    readonly property color alphaMedium: Qt.rgba(1, 1, 1, 0.10)
}
