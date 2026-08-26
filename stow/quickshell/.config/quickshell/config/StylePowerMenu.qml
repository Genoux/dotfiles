pragma Singleton

import Quickshell

import QtQuick
import qs

Singleton {
    readonly property int padding: StyleTokens.space12
    readonly property int itemWidth: 68
    readonly property int itemHeight: 56
    readonly property int itemGap: StyleTokens.space4
    readonly property int itemSpacing: StyleTokens.space6
    readonly property int iconSize: 16
    readonly property int labelSize: StyleTokens.fontSizeSm
    readonly property color text: Colors.base05
    readonly property color selectedBg: StyleTokens.alphaHairline
}
