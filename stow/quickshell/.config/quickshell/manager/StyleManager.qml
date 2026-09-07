pragma Singleton
import QtQuick
import Quickshell
import qs.config

Singleton {
    // Workspace text stays neutral regardless of the wallpaper palette.
    readonly property color textColor: "#ffffff"
    readonly property int width: StyleTokens.space20 * 47
    readonly property int height: StyleTokens.space20 * 35
    readonly property int sidebarWidth: StyleTokens.space20 * 10
    readonly property int margin: StyleTokens.space20 * 2
    readonly property int padding: StyleTokens.space20
    readonly property int rowHeight: StyleTokens.space20 * 3
    readonly property int inputHeight: StyleTokens.space20 * 2
    readonly property int dialogWidth: StyleTokens.space20 * 28
}
