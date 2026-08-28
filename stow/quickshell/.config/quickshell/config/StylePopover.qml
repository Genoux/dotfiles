import QtQuick
import Quickshell
pragma Singleton

Singleton {
    readonly property int padding: StyleTokens.space4
    // EXPERIMENTAL — was space4, then space2. One pixel: enough that the panel's
    // own hairline border still reads as its edge rather than merging into the
    // bar, and nothing more.
    readonly property int barGap: StyleTokens.space4
    readonly property int panelWidth: 320
    readonly property int minWidth: 184
    // Content like the tray menu populates asynchronously (QsMenuOpener is a
    // DBus round-trip) — without a floor, a popover opened before that
    // resolves has ~0 height and reads as hugging the bar rather than
    // floating above it.
    readonly property int minHeight: 32
    readonly property int contentPaddingH: StyleTokens.space16
    readonly property int rowHeight: 32
    readonly property int separatorHeight: StyleTokens.borderWidth

    // A single reversible transition keeps reveal and dismissal visually
    // identical and lets rapid toggles reverse from the current frame.
    readonly property int transitionDuration: StyleTokens.easeDurationFast
    readonly property real hiddenScale: 0.97

    readonly property int shadowRadius: 8
    readonly property int shadowSamples: 17

    // Tray context menu — a system right-click menu, not a bar widget panel.
    // It hugs its content instead of filling panelWidth, aligns to the icon's
    // edge instead of centring on it, and skips the spring reveal that marks a
    // widget panel opening.
    readonly property int contextMenuMinWidth: 160
    readonly property int contextMenuMaxWidth: 360
    readonly property int contextMenuRowHeight: 28
    readonly property int contextMenuPaddingH: StyleTokens.space12
    readonly property int contextMenuPaddingV: StyleTokens.space4

    // Weather popover — the hero and stats bands are taller than a list row
    // because each holds stacked figures rather than a single line.
    readonly property int weatherHeroHeight: 80
    readonly property int weatherStatsHeight: 52
    readonly property int forecastRowHeight: 38

    // Forecast range bar geometry
    readonly property int forecastBarHeight: 6
    readonly property int forecastBarRadius: 3
    // "Now" marker on today's range bar — a tick that crosses the bar rather
    // than a ringed dot. Qt Quick strokes small rounded rects badly (the inner
    // edge of border.width does not antialias), so the marker is drawn as a
    // plain fill with no border and reads crisply at this size.
    readonly property int forecastMarkerWidth: 4
    readonly property int forecastMarkerHeight: 16

    // Calendar popover — 40px square day cells match Material 3's date
    // container, and the width is derived from the grid so the cells define the
    // panel rather than the reverse. That derivation currently lands on exactly
    // panelWidth, so all popovers are the same width; keep it derived so the
    // grid stays correct if a cell dimension changes.
    readonly property int calendarCellSize: 40
    // Wider inset than the shared contentPaddingH: that value is tuned for
    // full-width menu rows, but a day grid ends in circles that bulge toward
    // the border, so the outer columns need more clearance to sit inside the
    // panel rather than against it.
    readonly property int calendarPaddingH: StyleTokens.space20
    readonly property int calendarWidth: calendarCellSize * 7 + calendarPaddingH * 2
    // Day circle sits inside the cell pitch so adjacent circles never touch.
    // Leave one spacing step between each day circle and its cell edge.
    readonly property int calendarDayCircle: calendarCellSize - StyleTokens.space4
    // The weekday initials are chrome, not content — a shorter row than the day
    // cells keeps them from reading as an eighth week.
    readonly property int calendarWeekdayRowHeight: 28
    // WCAG 2.2 AA floors a pointer target at 24px; 36 gives comfortable mouse
    // aim without the 44px touch-first sizing bloating the header.
    readonly property int calendarNavSize: 36
    readonly property int calendarNavHeight: 44
    readonly property real calendarOtherMonthOpacity: 0.38
    // One trackpad swipe emits many wheel deltas — debounce to one month per gesture.
    readonly property int calendarWheelDebounce: 220

    // Icon-row menus (record picker): a compact tile with the glyph on top
    // and a two-line caption under it, so four options fit in one bar.
    readonly property int tileWidth: 72
    readonly property int tileHeight: 58
    readonly property int tileIconSize: 20
    readonly property int tileBadgeSize: 10
    readonly property int tileSpacing: StyleTokens.space2
    readonly property int tileCaptionPadding: StyleTokens.space4

    // Shared panel chrome — the vertical rhythm every popover is built from.
    // A panel is: header, separator, then sections of rows.
    readonly property int headerHeight: 48
    readonly property int contentPaddingV: StyleTokens.space8
    // Empty-state body under a header (adapter off, no adapter). Tall enough
    // that the panel still reads as a surface rather than a title bar.
    readonly property int emptyStateHeight: 120

    // Section labels are eyebrows, not content: a shorter band than a row, in
    // the smallest type, so they group without competing with what they title.
    readonly property int sectionHeight: 26
    // Air above a section that follows content, so groups read as separate
    // without needing a rule between them.
    readonly property int sectionTopGap: StyleTokens.space6
    readonly property real sectionLabelOpacity: StyleTokens.opacityMuted
    readonly property real sectionLetterSpacing: 0.6

    // Two-line rows (name over status) need more height than the single-line
    // menu rowHeight, and inset so the hover fill floats inside the panel
    // instead of bleeding into its border.
    readonly property int listRowHeight: 44
    readonly property int listRowInset: StyleTokens.space4
    readonly property int listRowSpacing: StyleTokens.space2
    readonly property int listMaxHeight: 300

    // A row that opens a field under its label. The field is a control rather
    // than a caption, so the row grows by a control's height plus the gap that
    // separates it from the two lines above.
    readonly property int fieldHeight: 28
    readonly property int listRowExpandedHeight: listRowHeight + fieldHeight + StyleTokens.space8

    // Sound popover — a level band above the list of devices it applies to, with
    // a segmented control choosing which domain the panel is showing. The band is
    // taller than a menu row because it stacks a label over a full-width control.
    readonly property int levelBandHeight: 52
    readonly property int segmentBarHeight: 28
    // The header rule has ~16px of air above it, from the title centred in a 48px
    // header. Matching that below stops the rule reading as the tab bar's own
    // underline and lets it close the header instead.
    readonly property int segmentBandPaddingTop: StyleTokens.space16
    readonly property int segmentBandPaddingBottom: StyleTokens.space8
    readonly property int segmentPaddingH: StyleTokens.space10
    // A stream row carries a name line over its own slider, so it needs more than
    // the two-line device row: a slider's hit area is taller than a caption.
    readonly property int streamRowHeight: 44
    // The body under the segmented control is a FIXED height, not content-fit.
    // The panel hangs off the bar, so it grows upward — a content-fit body would
    // move the header and the segments themselves on every tab switch, and a
    // second click would land on a different tab than the one aimed at. Tabs that
    // hold still are worth more than a panel that hugs its shortest tab.
    readonly property int soundBodyHeight: 220

    readonly property int pillPaddingH: StyleTokens.space10
    readonly property int pillPaddingV: StyleTokens.space6

    // Ghost controls have no resting fill, so their padding is invisible and
    // must overhang the content margin — otherwise their glyph sits short of
    // the edge every other element aligns to.
    readonly property int ghostPaddingH: StyleTokens.space8
    readonly property int ghostPaddingV: StyleTokens.space4
    readonly property int iconButtonPadding: 5
}
