pragma Singleton

import Quickshell

import QtQuick
import qs

Singleton {
    readonly property int padding: 12
    readonly property int itemWidth: 68
    readonly property int itemHeight: 56
    readonly property int itemGap: 4
    readonly property int itemSpacing: 6
    readonly property int iconSize: 16
    readonly property int labelSize: 12
    readonly property color text: Colors.base05
    readonly property color selectedBg: Qt.rgba(1, 1, 1, 0.02)
}
