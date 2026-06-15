pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root

    property string connectionIcon: "offline"

    function iconForInterface(interfaceName) {
        if (!interfaceName)
            return "offline"

        if (interfaceName.startsWith("wl") || interfaceName.startsWith("wlan") || interfaceName.includes("wifi"))
            return "wireless"

        if (interfaceName.startsWith("eth") || interfaceName.startsWith("en"))
            return "wired"

        return "wired"
    }

    function refresh() {
        routeProcess.running = true
    }

    Process {
        id: routeProcess

        command: ["ip", "route", "get", "8.8.8.8"]

        stdout: StdioCollector {
            onStreamFinished: {
                const output = this.text.trim()
                if (!output) {
                    root.connectionIcon = "offline"
                    return
                }

                const match = output.match(/dev\s+(\w+)/)
                root.connectionIcon = match
                    ? root.iconForInterface(match[1])
                    : "offline"
            }
        }
    }

    Timer {
        interval: StyleTokens.pollIntervalNormal
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
