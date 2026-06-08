import Quickshell
import QtQuick
import qs
import qs.config
import qs.components

Item {
    id: root

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Pill {
        id: pill

        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd dd MMM HH:mm")
        foreground: Colors.base05
        interactive: true
        onClicked: Launchers.launchOrFocus("org.gnome.Calendar", "gnome-calendar", "org.gnome.Calendar")
    }
}
