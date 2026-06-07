pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property int refreshInterval: 600000
    property string icon: ""
    property string temperature: "--°C"

    function refresh() {
        weatherProcess.running = true
    }

    function open() {
        Quickshell.execDetached(["gnome-weather"])
    }

    Process {
        id: weatherProcess

        command: ["bash", "-lc", `
            location="\${WEATHER_CITY:-Montreal}"
            location="\${location// /%20}"
            curl -fsS --max-time 4 "https://wttr.in/\${location}?format=%c|%t" | tr -d '+'
        `]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("|")
                root.icon = parts[0]?.trim() ?? ""
                root.temperature = parts[1]?.trim() || "--°C"
            }
        }
    }

    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
