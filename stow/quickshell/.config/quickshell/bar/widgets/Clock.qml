import QtQuick
import Quickshell
import qs
import qs.components
import qs.config

Button {
    id: root

    required property var barWindow

    text: Qt.formatDateTime(clock.date, "ddd dd MMM HH:mm")
    fontSize: StyleBar.labelFontSize
    interactive: true
    active: popover.open
    onClicked: popover.toggle()

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    BarPopover {
        id: popover

        barWindow: root.barWindow
        anchorItem: root

        // Keep the calendar built so its window has settled geometry before
        // the first reveal.
        ClockPopover {
            active: popover.open
        }
    }
}
