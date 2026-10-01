import QtQuick
import qs
import qs.config

// Drawn, not the theme's record glyph: that SVG is a grey disc, and tinting
// its antialiased edge red leaves a dark fringe around the dot.
Rectangle {
    id: dot

    property bool paused: false

    implicitWidth: StyleRecording.dotSize
    implicitHeight: StyleRecording.dotSize
    radius: width / 2
    color: paused ? Colors.base04 : StyleRecording.signal

    // Opacity rather than colour, so the dot breathes without drifting hue.
    SequentialAnimation on opacity {
        running: !dot.paused
        loops: Animation.Infinite
        alwaysRunToEnd: true

        NumberAnimation {
            to: StyleRecording.breatheLow
            duration: StyleRecording.pulseDuration
            easing.type: StyleTokens.easePulse
        }

        NumberAnimation {
            to: 1
            duration: StyleRecording.pulseDuration
            easing.type: StyleTokens.easePulse
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: StyleTokens.motionFeedbackDuration
            easing.type: StyleTokens.easeFade
        }
    }
}
