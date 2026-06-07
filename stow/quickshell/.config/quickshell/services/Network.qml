pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import qs.config

Singleton {
    id: root

    property string connectionIcon: "network-offline-symbolic"

    function iconForInterface(interfaceName) {
        if (!interfaceName)
            return "network-offline-symbolic"

        if (interfaceName.startsWith("wl") || interfaceName.startsWith("wlan") || interfaceName.includes("wifi"))
            return "network-wireless-symbolic"

        if (interfaceName.startsWith("eth") || interfaceName.startsWith("en"))
            return "network-idle-symbolic"

        return "network-idle"
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
                    root.connectionIcon = "network-offline-symbolic"
                    return
                }

                const match = output.match(/dev\s+(\w+)/)
                root.connectionIcon = match
                    ? root.iconForInterface(match[1])
                    : "network-offline-symbolic"
            }
        }
    }

    Connections {
        target: Networking

        function onDevicesChanged() {
            root.refresh()
        }
    }

    Timer {
        interval: Style.pollIntervalNormal
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
