pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int rowSpacing: StyleTokens.space3

    readonly property int inlineIconSize: StyleControl.iconSizeSm
    readonly property int inlineIconPadding: StyleTokens.space4
    readonly property int inlineIconSpacing: StyleTokens.space4
    readonly property int inlineMaxIcons: 4
    readonly property int revealDuration: StyleTokens.easeDurationFast
}
