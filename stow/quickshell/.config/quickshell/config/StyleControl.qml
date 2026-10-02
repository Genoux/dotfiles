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

    // Segmented control — built like the island's tab dock: a borderless track,
    // one gap round every segment, and a fill whose radius is the track's less
    // that gap. A medium track with the base-unit gap lands the fill on the
    // standard 8px fill radius and a 28px height, the same as a list row's.
    readonly property int segmentHeight: 36
    readonly property int segmentInset: StyleTokens.space4
    readonly property int segmentTrackRadius: StyleTokens.radiusMd

    // Level bar -- a volume or brightness control as one rounded bar: tall enough
    // to grab, with the glyph inset in the fill that grows from it.
    readonly property int levelBarHeight: 36
    readonly property int levelBarIconSize: 22
    // Air between the value and the end of the fill it rides.
    readonly property int levelBarValuePadding: StyleTokens.space12
}
