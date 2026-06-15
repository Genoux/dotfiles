pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int infoWidth: 180
    readonly property int textFadeWidth: 10
    readonly property int controlsRevealDuration: 200
    readonly property int textLeftInset: 6 + StyleCava.visualWidth + 4
    readonly property int textRightInset: 8

    readonly property int trackHeight: StyleControl.iconSize + StyleControl.buttonPaddingVertical * 2
}
