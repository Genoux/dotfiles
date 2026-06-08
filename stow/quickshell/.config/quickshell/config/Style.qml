pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property string fontSans: "SF Pro Text"
    readonly property string fontMono: "JetBrainsMono Nerd Font Mono"
    readonly property string fontIcon: "JetBrainsMono Nerd Font"
    readonly property string fontEmoji: "Noto Color Emoji"

    readonly property int barHeight: 38
    readonly property int barMargin: 8
    readonly property int pillHeight: 24
    readonly property int pillWidth: 22
    readonly property int fontSizeSm: 12
    readonly property int fontSizeXs: 10
    readonly property int iconSizeMd: 18
    readonly property int iconSize: 14
    readonly property int iconSizeSm: 13
    readonly property int iconSizeXs: 12
    readonly property int fontSizeMedia: 11
    readonly property int mediaInfoWidth: 142
    readonly property int mediaHeight: 30
    readonly property int mediaPadding: 4
    readonly property int mediaControlsRevealDuration: 200
    readonly property int recordingPulseDuration: 1000
    readonly property real mediaBackgroundOpacity: 0.5
    readonly property real mediaBackgroundOpacityHover: 0.62
    readonly property int easeDurationFast: 150
    readonly property int easeDurationNormal: 200
    readonly property int easeDurationSlow: 320

    function surfaceAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }
    readonly property int windowTitleMaxWidth: 420
    readonly property int pollIntervalFast: 1000
    readonly property int pollIntervalNormal: 5000
    readonly property int pollIntervalSlow: 30000
    readonly property int radiusXs: 2
    readonly property int radiusSm: 4
    readonly property int radiusMd: 8

    readonly property int osdSize: 120
    readonly property int osdWidth: 132
    readonly property int osdHeight: 100
    readonly property int osdIconSize: 36
    readonly property int osdStepCount: 10
    readonly property int osdStepWidth: 8
    readonly property int osdStepHeight: 6
    readonly property int osdStepSpacing: 3
    readonly property int osdContentSpacing: 18
    readonly property int osdHideDelay: 2000
    readonly property int osdInitDelay: 250
    readonly property int osdBottomMargin: barHeight + barMargin + 16
    readonly property color osdStepEmpty: Qt.rgba(1, 1, 1, 0.2)
    readonly property color osdStepFilled: Qt.rgba(1, 1, 1, 1)
    readonly property color osdBorder: alphaLight

    function osdBackground(color) {
        return surfaceAlpha(color, 0.1)
    }

    readonly property color transparent: "transparent"
    readonly property color alphaLight: Qt.rgba(1, 1, 1, 0.05)
    readonly property color alphaMedium: Qt.rgba(1, 1, 1, 0.10)
    readonly property color recording: Qt.rgba(1, 0.11, 0.11, 0.28)
    readonly property color recordingHover: Qt.rgba(0.86, 0.16, 0.16, 0.73)
    readonly property color recordingPulse: Qt.rgba(1, 0.11, 0.11, 0.65)
    readonly property color privacyWebcamFill: Qt.rgba(0.30, 0.27, 0.77, 0.37)
    readonly property color privacyWebcamBorder: Qt.rgba(0.34, 0.28, 0.77, 0.37)
    readonly property color privacyMicFill: Qt.rgba(0.20, 1.00, 0.61, 0.20)
    readonly property color privacyMicBorder: Qt.rgba(0.22, 0.99, 0.58, 0.15)
    readonly property color privacyScreenFill: Qt.rgba(1.00, 0.43, 1.00, 0.20)
    readonly property color privacyScreenBorder: Qt.rgba(0.69, 0.33, 0.87, 0.87)
}
