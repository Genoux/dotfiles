import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.components
Pill {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, "ddd dd MMM HH:mm")
    foreground: Colors.base05
    interactive: true
    onClicked: clickProcess.running = true

    Process {
        id: clickProcess

        command: ["bash", "-lc", "hyprctl dispatch 'function() require(\"actions.launchers\").launchOrFocus(\"calcurse\", \"calcurse\") end'"]
    }
}
