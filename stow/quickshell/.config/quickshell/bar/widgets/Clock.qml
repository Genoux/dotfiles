import QtQuick
import Quickshell
import qs
import qs.components
import qs.config

Button {
    id: root

    required property var barWindow

    property bool calendarLoaded: false

    iconName: "x-office-calendar-symbolic"
    text: Qt.formatDateTime(clock.date, "ddd dd MMM HH:mm")
    iconTextSpacing: 0
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

        // Calendar grid is 42 cells deep; build it on first open instead of
        // eagerly per monitor at startup, then keep it loaded for later opens.
        Loader {
            active: root.calendarLoaded
            sourceComponent: calendarComponent
        }
    }

    Connections {
        target: popover

        function onOpenChanged() {
            if (popover.open)
                root.calendarLoaded = true;
        }
    }

    Component {
        id: calendarComponent

        ClockPopover {
            active: popover.open
        }
    }
}
