pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property int refreshInterval: 600000
    property string icon: "unknown"
    property string temperature: "--°C"

    readonly property var emojiToIcon: ({
        "☀️": "clear",
        "🌤️": "few-clouds",
        "⛅": "few-clouds",
        "🌥️": "few-clouds",
        "☁️": "overcast",
        "🌧️": "showers",
        "🌦️": "showers-scattered",
        "⛈️": "storm",
        "🌨️": "snow",
        "❄️": "snow",
        "🌫️": "fog",
        "🌙": "clear-night",
        "🌛": "few-clouds-night",
        "🌜": "few-clouds-night",
        "💨": "windy",
        "🌡️": "clear",
    })

    function iconForEmoji(emoji) {
        return emojiToIcon[emoji] ?? "unknown"
    }

    function refresh() {
        weatherProcess.running = true
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
                const emoji = parts[0]?.trim() ?? ""
                root.icon = root.iconForEmoji(emoji)
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
