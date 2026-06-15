pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property color backdrop: "#191818"
    readonly property real backdropOpacity: 0
    readonly property color surface: Qt.rgba(8 / 255, 8 / 255, 8 / 255, 0.3)
    readonly property color borderSubtle: Qt.rgba(1, 1, 1, 0.02)
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.2)
    readonly property real hiddenScale: 0.98
    readonly property int showDuration: 100
    readonly property int hideDuration: 100
}
