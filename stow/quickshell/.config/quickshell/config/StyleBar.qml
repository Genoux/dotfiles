pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int margin: StyleTokens.space8
    readonly property int topPadding: StyleTokens.space1
    readonly property int bottomPadding: StyleTokens.space3

    readonly property int windowTitleMaxWidth: 420
    readonly property color background: Qt.rgba(0, 0, 0, 0)

    readonly property int estimatedContentHeight: StyleControl.iconSizeMd
        + StyleControl.buttonPaddingVertical * 2
        + StyleGroup.chromeInset * 2

    readonly property int height: estimatedContentHeight + topPadding + bottomPadding
}
