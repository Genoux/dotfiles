import QtQuick
import Quickshell
pragma Singleton

Singleton {
    readonly property int iconSizeMd: 18
    readonly property int iconSize: 16
    readonly property int iconSizeSm: 13
    // Symbolic SVGs and font glyphs use uneven intrinsic padding — draw inside a scaled inner box.
    readonly property real iconVisualScale: 0.86
    readonly property int buttonPaddingHorizontal: StyleTokens.space4
    readonly property int buttonPaddingVertical: StyleTokens.space4
    readonly property int iconTextSpacing: StyleTokens.space3
    readonly property int buttonWidth: iconSize + buttonPaddingHorizontal * 2
    readonly property int buttonHeight: iconSize + buttonPaddingVertical * 2

    // Signal meter — four ascending bars read as a strength ramp rather than an
    // icon's five named buckets. Sized to stand in an icon box so it aligns
    // with the glyphs beside it in a list.
    readonly property int signalBarCount: 4
    readonly property int signalBarWidth: 3
    // Shortest bar plus one step per rung lands the tallest on iconSize - 2,
    // inside the box without touching its edge.
    readonly property int signalBarBase: 5
    readonly property int signalBarStep: 3
    readonly property int signalBarSpacing: StyleTokens.space2
}
