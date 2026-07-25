import QtQuick
import qs
import qs.components
import qs.config
import qs.services

PopoverPanel {
    id: root

    readonly property int heroIconSize: 44
    readonly property int forecastIconSize: 20
    readonly property int popoverWidth: StylePopover.panelWidth
    readonly property int padH: StylePopover.contentPaddingH

    // Formats "2026-07-04" → "Fri"
    function shortDayLabel(dateStr) {
        if (!dateStr)
            return ""
        const d = new Date(dateStr + "T12:00:00")
        return d.toLocaleDateString(Qt.locale(), "ddd")
    }

    // Week-wide min/max across all forecast days with numeric temps, for bar normalization
    readonly property real weekMin: {
        let m = Infinity
        for (let i = 0; i < WeatherState.forecast.length; i++) {
            const v = WeatherState.forecast[i].minTemp
            if (v !== null && v !== undefined && !isNaN(v))
                m = Math.min(m, v)
        }
        return isFinite(m) ? m : 0
    }

    readonly property real weekMax: {
        let m = -Infinity
        for (let i = 0; i < WeatherState.forecast.length; i++) {
            const v = WeatherState.forecast[i].maxTemp
            if (v !== null && v !== undefined && !isNaN(v))
                m = Math.max(m, v)
        }
        return isFinite(m) ? m : 0
    }

    // Normalize a temperature value to [0,1] across the week range.
    // Returns 0 when the range is zero or the value is invalid.
    function normalizeTemp(value) {
        const range = root.weekMax - root.weekMin
        if (range <= 0 || value === null || value === undefined || isNaN(value))
            return 0
        return Math.max(0, Math.min(1, (value - root.weekMin) / range))
    }

    Column {
        width: root.popoverWidth
        spacing: 0

        // Hero: location eyebrow + big icon/temp block + condition
        Item {
            width: parent.width
            height: 80

            // Location eyebrow — decoration text uses fontSizeXs per design
            Text {
                id: locationLabel

                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width - root.padH * 2)
                text: WeatherState.locationName.length > 0 ? WeatherState.locationName : "Weather"
                color: Colors.base04
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeXs
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8
                elide: Text.ElideRight
            }

            // Weather SVGs carry embedded colors — render without overlay
            Image {
                id: heroIcon

                anchors.top: locationLabel.bottom
                anchors.topMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: -36
                source: IconRegistry.weatherIcon(WeatherState.icon)
                width: root.heroIconSize
                height: root.heroIconSize
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(root.heroIconSize, root.heroIconSize)
            }

            // Temperature — the glanceable number
            Text {
                id: heroTemp

                anchors.left: heroIcon.right
                anchors.leftMargin: 8
                anchors.verticalCenter: heroIcon.verticalCenter
                anchors.verticalCenterOffset: -4
                text: WeatherState.temperature
                color: Colors.base05
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeXl
                font.weight: Font.Light
            }

            Text {
                anchors.left: heroIcon.right
                anchors.leftMargin: 9
                anchors.right: parent.right
                anchors.rightMargin: root.padH
                anchors.top: heroTemp.bottom
                anchors.topMargin: -2
                text: WeatherState.description
                color: Colors.base05
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
                elide: Text.ElideRight
            }

        }

        Rectangle {
            width: parent.width
            height: StylePopover.separatorHeight
            color: StyleOverlay.borderSubtle
        }

        // Stats row: FEELS / HUMIDITY / WIND in equal thirds
        Item {
            width: parent.width
            height: 48

            Row {
                anchors.fill: parent

                Repeater {
                    model: [
                        { label: "FEELS", value: WeatherState.feelsLike },
                        { label: "HUMIDITY", value: WeatherState.humidity },
                        { label: "WIND", value: WeatherState.wind }
                    ]

                    Item {
                        required property var modelData

                        width: parent.width / 3
                        height: parent.height

                        Text {
                            id: statLabel

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            text: modelData.label
                            color: Colors.base04
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeXs
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.6
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: statLabel.bottom
                            anchors.topMargin: 3
                            text: modelData.value
                            color: Colors.base05
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeSm
                        }

                    }

                }

            }

        }

        Rectangle {
            width: parent.width
            height: StylePopover.separatorHeight
            color: StyleOverlay.borderSubtle
        }

        // Forecast rows: day label + icon + temperature range bar
        Repeater {
            id: forecastRepeater

            model: WeatherState.forecast

            Item {
                id: forecastRow

                required property var modelData

                width: root.popoverWidth
                height: StylePopover.rowHeight

                Text {
                    id: dayText

                    anchors.left: parent.left
                    anchors.leftMargin: root.padH
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.shortDayLabel(modelData.date)
                    color: Colors.base05
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeSm
                    width: 28
                }

                // Weather SVGs carry embedded colors
                Image {
                    id: forecastIcon

                    anchors.left: dayText.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    source: IconRegistry.weatherIcon(modelData.icon)
                    width: root.forecastIconSize
                    height: root.forecastIconSize
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(root.forecastIconSize, root.forecastIconSize)
                }

                // Range bar lane
                Item {
                    id: barLane

                    anchors.left: forecastIcon.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: root.padH
                    anchors.verticalCenter: parent.verticalCenter
                    height: 24

                    readonly property real barLaneWidth: width - minTempLabel.width - maxTempLabel.width - 8

                    // Min temp label
                    Text {
                        id: minTempLabel

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: forecastRow.modelData.minC
                        color: Colors.base05
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeXs
                    }

                    // Track background
                    Rectangle {
                        id: barTrack

                        anchors.left: minTempLabel.right
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: barLane.barLaneWidth
                        height: StylePopover.forecastBarHeight
                        radius: StylePopover.forecastBarRadius
                        color: Qt.rgba(Colors.base04.r, Colors.base04.g, Colors.base04.b, 0.15)

                        readonly property real fillStart: root.normalizeTemp(forecastRow.modelData.minTemp)
                        readonly property real fillEnd: root.normalizeTemp(forecastRow.modelData.maxTemp)

                        // Filled accent segment — sized/positioned by normalized progress
                        Rectangle {
                            x: barTrack.fillStart * barTrack.width
                            y: 0
                            width: Math.max(0, (barTrack.fillEnd - barTrack.fillStart) * barTrack.width)
                            height: parent.height
                            radius: parent.radius
                            color: Colors.base0B
                            visible: forecastRow.modelData.minTemp !== null && forecastRow.modelData.maxTemp !== null
                        }

                    }

                    // Max temp label
                    Text {
                        id: maxTempLabel

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: forecastRow.modelData.maxC
                        color: Colors.base05
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeXs
                    }

                }

            }

        }

        // Collapse gracefully when forecast is empty
        Item {
            visible: WeatherState.forecast.length === 0
            width: parent.width
            height: 0
        }

        Item { width: 1; height: 8 }

    }

}
