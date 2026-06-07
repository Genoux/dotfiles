import Quickshell
import QtQuick
import qs
import qs.config
import qs.components

Pill {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, "ddd dd MMM HH:mm")
    foreground: Colors.base05
    interactive: true
    onClicked: Launchers.launchOrFocus("calcurse", "calcurse")
}
