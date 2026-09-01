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
    // Deliberately off the shared radius scale: radiusXs is half a step's
    // height, which rounds a 8x6 mark into a dot. These read as ticks on a
    // meter, so they keep square ends with the corners only knocked off.
    readonly property int stepRadius: 2
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
    // Hyprland's blur radius is global, so OSDs temper it through their shared
    // glass opacity rather than weakening blur for every shell surface.
    readonly property real backgroundAlpha: 0.14

    function background(color) {
        return StyleTokens.surfaceAlpha(color, backgroundAlpha)
    }
}
