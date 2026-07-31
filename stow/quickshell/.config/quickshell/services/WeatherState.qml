pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property int refreshInterval: 600000
    readonly property int retryInterval: 30000

    // False until the first successful fetch; keeps the retry timer running
    // so a failed fetch at startup or resume doesn't strand "--°C" for 10 min.
    property bool hasData: false

    // Bar display
    property string icon: "unknown"
    property string temperature: "--°C"
    // Numeric form of the above, for plotting the "now" marker on the forecast
    // range bars. NaN while there is no data.
    property real currentTemp: NaN

    // Popover detail — current conditions
    property string description: ""
    property string feelsLike: "--°C"
    property string humidity: "--%"
    property string wind: "--"
    property string locationName: ""

    // 3-day forecast: [{date, icon, minC, maxC, description}]
    property var forecast: []

    readonly property var codeToIcon: ({
        113: "clear",
        116: "few-clouds",
        119: "overcast",
        122: "overcast",
        143: "fog",
        176: "showers-scattered",
        179: "snow",
        182: "showers",
        185: "showers",
        200: "storm",
        227: "snow",
        230: "snow",
        248: "fog",
        260: "fog",
        263: "showers-scattered",
        266: "showers",
        281: "showers",
        284: "showers",
        293: "showers-scattered",
        296: "showers",
        299: "showers-scattered",
        302: "showers",
        305: "showers",
        308: "showers",
        311: "showers",
        314: "showers",
        317: "showers",
        320: "showers",
        323: "snow",
        326: "snow",
        329: "snow",
        332: "snow",
        335: "snow",
        338: "snow",
        350: "showers",
        353: "showers-scattered",
        356: "showers",
        359: "showers",
        362: "snow",
        365: "snow",
        368: "snow",
        371: "snow",
        374: "showers",
        377: "showers",
        386: "storm",
        389: "storm",
        392: "storm",
        395: "storm",
    })

    function iconForCode(code) {
        return codeToIcon[parseInt(code)] ?? "unknown"
    }

    function refresh() {
        weatherProcess.running = true
    }

    Process {
        id: weatherProcess

        command: ["bash", "-lc", `
            location="\${WEATHER_CITY:-Montreal}"
            location="\${location// /%20}"
            curl -fsS --max-time 4 "https://wttr.in/\${location}?format=j1"
        `]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                let data
                try {
                    data = JSON.parse(this.text.trim())
                } catch (e) {
                    return
                }

                const cc = data?.current_condition?.[0]
                if (!cc)
                    return

                root.hasData = true

                const code = parseInt(cc.weatherCode ?? "113")
                root.icon = root.iconForCode(code)
                root.temperature = (cc.temp_C ?? "--") + "°C"
                root.currentTemp = parseFloat(cc.temp_C ?? "NaN")
                root.description = cc.weatherDesc?.[0]?.value ?? ""
                root.feelsLike = (cc.FeelsLikeC ?? "--") + "°C"
                root.humidity = (cc.humidity ?? "--") + "%"
                root.wind = (cc.windspeedKmph ?? "--") + " km/h " + (cc.winddir16Point ?? "")

                const na = data?.nearest_area?.[0]
                root.locationName = na?.areaName?.[0]?.value ?? ""

                const days = data?.weather ?? []
                root.forecast = days.map(day => {
                    // use mid-day hourly slot for description
                    const mid = day.hourly?.[Math.floor((day.hourly?.length ?? 0) / 2)] ?? {}
                    const dayCode = parseInt(mid.weatherCode ?? "113")
                    const minNum = parseFloat(day.mintempC ?? "NaN")
                    const maxNum = parseFloat(day.maxtempC ?? "NaN")
                    return {
                        date: day.date ?? "",
                        icon: root.iconForCode(dayCode),
                        minC: (day.mintempC ?? "--") + "°C",
                        maxC: (day.maxtempC ?? "--") + "°C",
                        // numeric temps for range-bar math (NaN when data missing)
                        minTemp: isNaN(minNum) ? null : minNum,
                        maxTemp: isNaN(maxNum) ? null : maxNum,
                        description: mid.weatherDesc?.[0]?.value ?? "",
                    }
                })
            }
        }
    }

    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: root.retryInterval
        running: !root.hasData
        repeat: true
        onTriggered: root.refresh()
    }

    // Re-fetch as soon as connectivity returns (e.g. after suspend/resume)
    // instead of waiting out the remainder of the 10-minute cycle.
    Connections {
        target: Network

        function onIsOnlineChanged() {
            if (Network.isOnline)
                root.refresh()
        }
    }
}
