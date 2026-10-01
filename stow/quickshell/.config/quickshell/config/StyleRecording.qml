import QtQuick
import Quickshell
pragma Singleton

Singleton {
    readonly property int pulseDuration: 1000
    readonly property int expandDuration: StyleTokens.motionFeedbackDuration
    readonly property color fill: Qt.rgba(0.95, 0.05, 0.05, 0.96)
    readonly property color pulse: Qt.rgba(1, 0.11, 0.11, 0.5)
    readonly property color paused: Qt.rgba(0.95, 0.05, 0.05, 0.4)
}
