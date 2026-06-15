pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int margin: 8
    readonly property int topPadding: 2
    readonly property int bottomPadding: 6

    readonly property int windowTitleMaxWidth: 420
    readonly property color background: Qt.rgba(0, 0, 0, 0)

    readonly property int estimatedContentHeight: StyleControl.iconSizeMd
        + StyleControl.buttonPaddingVertical * 2
        + StyleGroup.chromeInset * 2

    readonly property int height: estimatedContentHeight + topPadding + bottomPadding
}
