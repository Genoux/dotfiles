import QtQuick
import Quickshell
pragma Singleton

Singleton {
    readonly property int padding: 4
    readonly property int barGap: 2
    readonly property int panelWidth: 320
    readonly property int minWidth: 184
    readonly property int contentPaddingH: 16
    readonly property int rowHeight: 32
    readonly property int separatorHeight: 1
    readonly property int showDuration: 100
    readonly property int hideDuration: 100
    readonly property real hiddenScale: 0.98

    // Weather popover — forecast range bar geometry
    readonly property int forecastBarHeight: 4
    readonly property int forecastBarRadius: 2

    // Calendar popover — cell geometry derived from panelWidth so cells fill the panel.
    // (panelWidth - 2 * contentPaddingH) / 7 columns, rounded down to keep cells crisp.
    readonly property int calendarCellSize: Math.floor((panelWidth - contentPaddingH * 2) / 7)
    readonly property int calendarCellHeight: 32
}
