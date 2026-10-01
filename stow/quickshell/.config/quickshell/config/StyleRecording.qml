pragma Singleton

import Quickshell
import QtQuick

// A recording is signalled by the dot alone, never a red fill: a red block
// outshouts everything else on screen. The red is fixed
// rather than a Colors role, like the privacy dots — a recording signal must
// read the same under every wallpaper palette.
Singleton {
    readonly property int pulseDuration: 1000
    readonly property int expandDuration: StyleTokens.motionFeedbackDuration
    readonly property int dotSize: 8
    readonly property real breatheLow: 0.45
    readonly property color signal: "#FF453A"
}
