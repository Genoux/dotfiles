pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int infoWidth: 180
    readonly property int textFadeWidth: 10
    readonly property int controlsRevealDuration: StyleTokens.easeDurationNormal
    readonly property int controlsHoverDelay: 300
    // Keep the visualizer and its following text gap explicit in the derived inset.
    readonly property int textLeftInset: StyleTokens.space6 + StyleCava.visualWidth + StyleTokens.space4
    readonly property int textRightInset: StyleTokens.space8

    readonly property int trackHeight: StyleControl.iconSize + StyleControl.buttonPaddingVertical * 2
}
