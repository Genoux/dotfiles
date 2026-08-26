pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int width: 132
    readonly property int height: 100
    readonly property int iconSize: 36
    readonly property int stepCount: 10
    readonly property int stepWidth: 8
    readonly property int stepHeight: 6
    readonly property int stepSpacing: StyleTokens.space3
    readonly property int contentSpacing: 18
    readonly property int hideDelay: 2000
    readonly property int initDelay: 250
    // Long enough to cover the property churn that follows a default-sink swap:
    // PwObjectTracker rebinds, the node's volume arrives, and its ready flag
    // flickers on the way through.
    readonly property int settleDelay: 600
    readonly property color stepEmpty: Qt.rgba(1, 1, 1, 0.2)
    readonly property color stepFilled: Qt.rgba(1, 1, 1, 1)
    readonly property color border: StyleTokens.alphaLight

    function background(color) {
        return StyleTokens.surfaceAlpha(color, 0.1)
    }
}
