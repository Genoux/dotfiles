import Quickshell
import QtQuick
import qs
import qs.config
import qs.components

Button {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, "ddd dd MMM HH:mm")
    fontSize: StyleTokens.fontSizeSm
    foreground: Colors.base05
    interactive: true
    onClicked: ShellActions.launchOrFocus("org.gnome.Calendar", "gnome-calendar", "org.gnome.Calendar")
}
