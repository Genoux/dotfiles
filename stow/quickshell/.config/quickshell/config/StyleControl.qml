import QtQuick
import Quickshell
pragma Singleton

Singleton {
    readonly property int iconSizeMd: 18
    readonly property int iconSize: 16
    readonly property int iconSizeSm: 13
    // Symbolic SVGs and font glyphs use uneven intrinsic padding — draw inside a scaled inner box.
    readonly property real iconVisualScale: 0.86
    readonly property int buttonPaddingHorizontal: 4
    readonly property int buttonPaddingVertical: 4
    readonly property int iconTextSpacing: 3
    readonly property int buttonWidth: iconSize + buttonPaddingHorizontal * 2
    readonly property int buttonHeight: iconSize + buttonPaddingVertical * 2
}
