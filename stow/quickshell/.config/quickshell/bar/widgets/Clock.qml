import QtQuick
import Quickshell
import qs
import qs.components
import qs.config

Button {
    text: Qt.formatDateTime(clock.date, "ddd dd MMM HH:mm")
    fontSize: StyleTokens.fontSizeSm
    foreground: Colors.base05
    interactive: true
    paddingHorizontal: 6
    // ponytail: plain launch — repeated clicks stack dashboard instances; upgrade to a pkill-toggle if that annoys
    onClicked: ShellActions.run("waylandar-dashboard")

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

}
