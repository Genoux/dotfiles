pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int pulseDuration: 1000
    readonly property int expandDuration: 200

    readonly property color fill: Qt.rgba(1, 0.11, 0.11, 0.28)
    readonly property color pulse: Qt.rgba(1, 0.11, 0.11, 0.65)
}
