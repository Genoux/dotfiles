pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root

    property string keyboardName: ""
    property string layout: "EN"

    function refresh() {
        if (devicesProcess.running) {
            devicesProcess.running = false
        }
        devicesProcess.running = true
    }

    function switchLayout() {
        const target = root.keyboardName.length > 0 ? root.keyboardName : "current"
        switchLayoutProcess.command = ["hyprctl", "switchxkblayout", target, "next"]
        if (switchLayoutProcess.running)
            switchLayoutProcess.running = false
        switchLayoutProcess.running = true
    }

    function formatLayout(rawLayout) {
        const normalized = String(rawLayout).toLowerCase()
        return normalized.includes("french") || normalized.includes("canada") ? "FR" : "EN"
    }

    function applyDeviceLine(line) {
        const parts = line.trim().split("\t")
        if (parts.length < 2) {
            return
        }

        root.keyboardName = parts[0]
        root.layout = root.formatLayout(parts[1])
    }

    Process {
        id: devicesProcess

        command: ["bash", "-lc", `hyprctl devices -j 2>/dev/null | jq -r '.keyboards[] | select(.main == true) | [.name, .active_keymap] | @tsv' | head -n1`]

        stdout: StdioCollector {
            onStreamFinished: root.applyDeviceLine(this.text)
        }
    }

    Process {
        id: switchLayoutProcess
        running: false
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activelayout") {
                return
            }

            const separator = event.data.indexOf(",")
            if (separator < 0) {
                return
            }

            root.keyboardName = event.data.slice(0, separator)
            root.layout = root.formatLayout(event.data.slice(separator + 1))
        }
    }

    Timer {
        interval: StyleTokens.pollIntervalFast
        running: root.keyboardName.length === 0
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
