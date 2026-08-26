pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int padding: StyleTokens.space3
    readonly property real borderOpacity: 0.07
    readonly property int borderWidth: StyleTokens.borderWidth
    readonly property int chromeInset: borderWidth + padding
}
