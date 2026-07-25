import QtQuick
import Quickshell
import qs
import qs.components
import qs.config

Button {
    id: root

    required property var barWindow

    text: Qt.formatDateTime(clock.date, "ddd dd MMM HH:mm")
    fontSize: StyleTokens.fontSizeSm
    foreground: Colors.base05
    interactive: true
    paddingHorizontal: 6
    active: popover.open
    onClicked: popover.open = !popover.open

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    BarPopover {
        id: popover

        barWindow: root.barWindow
        anchorItem: root

        ClockPopover {
            active: popover.open
        }
    }
}
