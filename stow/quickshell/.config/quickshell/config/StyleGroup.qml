pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int padding: 3
    readonly property real borderOpacity: 0.07
    readonly property int borderWidth: 1
    readonly property int chromeInset: borderWidth + padding
}
