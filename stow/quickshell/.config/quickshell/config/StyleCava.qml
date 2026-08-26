import QtQuick
import Quickshell
pragma Singleton

Singleton {
    readonly property int displayBars: 4
    readonly property int analyzeBars: 4
    readonly property int barWidth: 3
    readonly property int barHeight: 12
    readonly property int spacing: StyleTokens.space2
    readonly property int framerate: 60
    readonly property int asciiMaxRange: 4000
    readonly property int noiseReduction: 20
    readonly property bool monstercat: true
    readonly property int animationDuration: StyleTokens.easeDurationFast
    readonly property int silenceThreshold: 2
    readonly property real maxFill: 1
    readonly property real snapThreshold: 4.5
    readonly property int snapHeight: 3
    readonly property real inactiveOpacity: 0.35
    readonly property int visualWidth: displayBars * barWidth + ((displayBars - 1) * spacing)
}
