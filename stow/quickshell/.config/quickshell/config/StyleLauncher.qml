pragma Singleton

import Quickshell

import QtQuick
import qs

Singleton {
    readonly property int width: 600
    readonly property int padding: 10
    readonly property int spacing: 4
    readonly property int searchHeight: 40
    readonly property int resultHeight: 40
    readonly property int emptyHeight: 200
    readonly property int listMaxHeight: 300
    readonly property int iconSize: 24
    readonly property int maxResults: 100
    readonly property color text: Colors.base05
    readonly property color selection: Qt.rgba(225 / 255, 225 / 255, 225 / 255, 0.2)
    readonly property color searchBg: Qt.rgba(0, 0, 0, 0.08)
    readonly property color selectedBg: Qt.rgba(1, 1, 1, 0.02)
    readonly property color placeholder: Qt.rgba(1, 1, 1, 0.4)
}
