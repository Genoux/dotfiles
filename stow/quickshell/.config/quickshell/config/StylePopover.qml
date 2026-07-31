import QtQuick
import Quickshell
pragma Singleton

Singleton {
    readonly property int padding: 4
    readonly property int barGap: 4
    readonly property int panelWidth: 320
    readonly property int minWidth: 184
    // Content like the tray menu populates asynchronously (QsMenuOpener is a
    // DBus round-trip) — without a floor, a popover opened before that
    // resolves has ~0 height and reads as hugging the bar rather than
    // floating above it.
    readonly property int minHeight: 32
    readonly property int contentPaddingH: 16
    readonly property int rowHeight: 32
    readonly property int separatorHeight: 1

    // Plain fade + subtle scale from the bar edge — a slight spring overshoot
    // on the way in gives it some life without a jarring geometry morph.
    readonly property int showDuration: 180
    readonly property int hideDuration: 120
    readonly property real hiddenScale: 0.94
    readonly property real showOvershoot: 1.2

    // Swapping popovers reads as one panel travelling along the bar, so the
    // glide is slower than a plain reveal and skips the spring entirely.
    readonly property int handoffDuration: 260
    // A dismissal only counts as part of the same click as the next open if it
    // lands within this window; anything slower is treated as a cold open.
    readonly property int handoffGrace: 250

    // Tray context menu — a system right-click menu, not a bar widget panel.
    // It hugs its content instead of filling panelWidth, aligns to the icon's
    // edge instead of centring on it, and skips the spring reveal that marks a
    // widget panel opening.
    readonly property int contextMenuMinWidth: 160
    readonly property int contextMenuMaxWidth: 360
    readonly property int contextMenuRowHeight: 28
    readonly property int contextMenuPaddingH: 12
    readonly property int contextMenuPaddingV: 4

    // Weather popover — forecast range bar geometry
    readonly property int forecastBarHeight: 6
    readonly property int forecastBarRadius: 3
    // "Now" marker on today's range bar — a tick that crosses the bar rather
    // than a ringed dot. Qt Quick strokes small rounded rects badly (the inner
    // edge of border.width does not antialias), so the marker is drawn as a
    // plain fill with no border and reads crisply at this size.
    readonly property int forecastMarkerWidth: 4
    readonly property int forecastMarkerHeight: 16

    // Calendar popover — geometry follows desktop calendar conventions rather
    // than the shared panelWidth, which other popovers still use. 40px square
    // day cells match Material 3's date container; width is derived from the
    // grid so the cells define the panel, not vice versa.
    readonly property int calendarCellSize: 40
    // Wider inset than the shared contentPaddingH: that value is tuned for
    // full-width menu rows, but a day grid ends in circles that bulge toward
    // the border, so the outer columns need more clearance to sit inside the
    // panel rather than against it.
    readonly property int calendarPaddingH: 20
    readonly property int calendarWidth: calendarCellSize * 7 + calendarPaddingH * 2
    // Day circle sits inside the cell pitch so adjacent circles never touch.
    readonly property int calendarDayCircle: calendarCellSize - 4
    // The weekday initials are chrome, not content — a shorter row than the day
    // cells keeps them from reading as an eighth week.
    readonly property int calendarWeekdayRowHeight: 28
    // WCAG 2.2 AA floors a pointer target at 24px; 36 gives comfortable mouse
    // aim without the 44px touch-first sizing bloating the header.
    readonly property int calendarNavSize: 36
    readonly property int calendarHeroHeight: 48
    readonly property int calendarNavHeight: 44
    readonly property real calendarOtherMonthOpacity: 0.38
    readonly property real calendarWeekdayOpacity: 0.6
    // One trackpad swipe emits many wheel deltas — debounce to one month per gesture.
    readonly property int calendarWheelDebounce: 220
}
