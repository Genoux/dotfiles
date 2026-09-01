import QtQuick
import Quickshell
pragma Singleton

Singleton {
    readonly property int iconSizeMd: 18
    readonly property int iconSize: 16
    readonly property int iconSizeSm: 13
    // MacTahoe symbolic assets are authored for compact controls. A shared
    // optical inset keeps the normal 16px slot at a crisp 14px draw size.
    readonly property real symbolicIconVisualScale: 0.875
    readonly property int buttonPaddingHorizontal: StyleTokens.space4
    readonly property int buttonPaddingVertical: StyleTokens.space4
    readonly property int iconTextSpacing: StyleTokens.space2
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

    // Level slider — a track thin enough to read as a scale rather than a filled
    // bar, and a handle just wide enough to aim at. The 24px pointer floor is met
    // by the slider's hit area, not by the handle's own size.
    readonly property int sliderTrackHeight: 4
    readonly property int sliderHandleSize: 12
    readonly property int sliderHitHeight: 24
    // One wheel notch. Coarse enough that a flick crosses the range, fine enough
    // to land on a level you meant.
    readonly property real sliderStep: 0.05

    // Toggle — a real switch rather than a pill reading "On"/"Off". Track height
    // sits between the eyebrow and body type sizes so it reads as a control in a
    // header without outweighing the title beside it.
    readonly property int toggleWidth: 34
    readonly property int toggleHeight: 18
    // Breathing room around the knob inside the track.
    readonly property int toggleInset: 2
}
