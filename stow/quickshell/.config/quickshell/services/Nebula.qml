pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root

    readonly property string unit: "nebula.service"
    property bool active: false

    function toggle() {
        if (toggleProcess.running)
            return
        toggleProcess.command = ["systemctl", "--user", root.active ? "stop" : "start", root.unit]
        toggleProcess.running = true
    }

    Process {
        id: statusProcess

        command: ["systemctl", "--user", "is-active", "--quiet", root.unit]
        onExited: (exitCode) => root.active = exitCode === 0
    }

    Process {
        id: toggleProcess

        onExited: statusProcess.running = true
    }

    // Nebula runs with Restart=no and can exit on its own, so a toggle alone
    // would leave the icon lit after a crash.
    Timer {
        interval: StyleTokens.pollIntervalNormal
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusProcess.running = true
    }
}
