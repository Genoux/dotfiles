import QtQuick
import Quickshell
import qs
pragma Singleton

Singleton {
    // The current or selected thing: a segment, a dock tab, an active tile, a
    // toggle that is on, a primary transport button. Solid light with dark
    // content, so it is the one fill on a surface that is not translucent.
    readonly property color chipFill: Colors.base07
    readonly property color chipContent: Colors.base00
    // Icon-sized chips and wells -- dock tabs, row glyphs, calendar days -- are
    // rounded squares, not circles: a circle per row reads as a list of avatars.
    readonly property int chipRadius: StyleTokens.radiusSm

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
    readonly property int sliderTrackHeight: 6
    readonly property int sliderHandleSize: 12
    readonly property int sliderHitHeight: 24
    // One wheel notch. Coarse enough that a flick crosses the range, fine enough
    // to land on a level you meant.
    readonly property real sliderStep: 0.05

    // Toggle — a real switch rather than a pill reading "On"/"Off".
    readonly property int toggleWidth: 40
    readonly property int toggleHeight: 24
    // Breathing room around the knob inside the track.
    readonly property int toggleInset: 3

    // Segmented control — built like the island's tab dock: a borderless
    // rounded track, one gap round every segment, and a chip whose radius is the
    // track's less that gap.
    readonly property int segmentHeight: 36
    readonly property int segmentInset: StyleTokens.space3
    readonly property int segmentTrackRadius: StyleTokens.radiusMd

    // Level bar -- a volume or brightness control as one glass slab, tall enough
    // to grab, with the label and value inside it.
    readonly property int levelBarHeight: 44
    readonly property int levelBarRadius: StyleTokens.radiusMd
    // The fill stacks on the track: 3% under 4% comes to the dock's 7%, so a
    // full bar is the same tone as the dock and the cards beside it, and the
    // empty part a shade lighter than the island.
    readonly property color levelBarTrack: Qt.rgba(1, 1, 1, 0.03)
    readonly property color levelBarFill: Qt.rgba(1, 1, 1, 0.04)
    readonly property int levelBarPadding: StyleTokens.space16
    readonly property int levelBarHandleWidth: 3
    readonly property int levelBarHandleHeight: 20
    // How far inside the fill's leading edge the handle sits.
    readonly property int levelBarHandleInset: StyleTokens.space10
    // The least air the handle keeps from the label and the value.
    readonly property int levelBarHandleClearance: StyleTokens.space12
    readonly property real levelBarScrubScale: 1.15
}
