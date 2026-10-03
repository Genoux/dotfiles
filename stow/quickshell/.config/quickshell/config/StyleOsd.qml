pragma Singleton

import Quickshell

import QtQuick

Singleton {
    readonly property int width: 280
    readonly property int padding: StyleTokens.space8
    readonly property int height: StyleControl.levelBarHeight + padding * 2
    readonly property int radius: StyleControl.levelBarRadius + padding
    readonly property int hideDelay: 2000
    readonly property int initDelay: 250
    // Long enough to cover the property churn that follows a default-sink swap:
    // PwObjectTracker rebinds, the node's volume arrives, and its ready flag
    // flickers on the way through.
    readonly property int settleDelay: 600
    // How long a change made from the shell's own controls stays unannounced: the
    // audio server's echo of the write arrives after the write itself.
    readonly property int suppressDelay: 800
}
