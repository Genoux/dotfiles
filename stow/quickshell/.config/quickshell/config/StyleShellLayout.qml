pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int osdBottomMargin: StyleBar.height + StyleBar.margin + 32
    readonly property int notificationBottomMargin: StyleBar.height + StyleBar.margin - 6
    readonly property int notificationRightMargin: StyleBar.margin - 2
}
