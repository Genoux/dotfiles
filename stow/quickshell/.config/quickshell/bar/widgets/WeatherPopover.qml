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
    readonly property int forecastRowCount: WeatherState.forecastDayCount
    // Reserved up front from the same tokens the bands below are built from, so
    // the panel does not resize as the forecast arrives. Deriving it from
    // content instead would make it jump mid-reveal; hardcoding the figures
    // would let it silently desync from the bands.
    readonly property int popoverContentHeight: StylePopover.weatherHeroHeight
        + StylePopover.separatorHeight
        + StylePopover.weatherStatsHeight
        + StylePopover.separatorHeight
        + StylePopover.sectionHeight
        + forecastRowCount * StylePopover.forecastRowHeight
        + StylePopover.contentPaddingV

    property real dataOpacity: 0

    function revealData() {
        if (!active || !WeatherState.hasData || dataOpacity >= 1)
            return

        dataFade.restart()
    }

    onActiveChanged: {
        if (active)
            Qt.callLater(revealData)
    }

    onDismissFinished: {
        if (!active)
            dataOpacity = 0
    }

    Connections {
        target: WeatherState

        function onHasDataChanged() {
            if (WeatherState.hasData)
                Qt.callLater(root.revealData)
        }
    }

    NumberAnimation {
        id: dataFade

        target: root
        property: "dataOpacity"
        to: 1
        duration: StyleTokens.easeDurationFast
        easing.type: StyleTokens.easeStandard
    }

    // Shared column geometry — the axis labels in the section header must land
    // exactly on the ends of the track in the rows below, or the scale they
    // describe reads as decoration instead of an axis.
    readonly property int dayLabelWidth: 38
    readonly property int columnGap: 8
    readonly property int tempLabelWidth: 32
    readonly property int trackLeft: padH + dayLabelWidth + columnGap + forecastIconSize + columnGap + tempLabelWidth + columnGap
    readonly property int trackRight: popoverWidth - padH - tempLabelWidth - columnGap
    readonly property int trackWidth: Math.max(0, trackRight - trackLeft)
    readonly property int minLabelX: trackLeft - columnGap - tempLabelWidth

    readonly property string todayDate: Qt.formatDate(new Date(), "yyyy-MM-dd")

    // Formats "2026-07-04" → "Fri", or "Today" for the current day
    function shortDayLabel(dateStr) {
        if (!dateStr)
            return ""
        if (dateStr === root.todayDate)
            return "Today"
        const d = new Date(dateStr + "T12:00:00")
        return d.toLocaleDateString(Qt.locale(), "ddd")
    }

    // Whole degrees only — the unit is stated once in the hero, so repeating
    // "°C" on every bound just crowds the row.
    function degreeLabel(value) {
        if (value === null || value === undefined || isNaN(value))
            return "--°"
        return Math.round(value) + "°"
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

    Item {
        width: root.popoverWidth
        height: root.popoverContentHeight
        implicitWidth: width
        implicitHeight: height

        Column {
            id: weatherContent

            width: root.popoverWidth
            bottomPadding: StylePopover.contentPaddingV
            spacing: 0
            opacity: root.dataOpacity

        // Hero: location eyebrow + big icon/temp block + condition
        Item {
            width: parent.width
            height: StylePopover.weatherHeroHeight

            EyebrowLabel {
                id: locationLabel

                anchors.top: parent.top
                anchors.topMargin: StyleTokens.space10
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width - root.padH * 2)
                text: WeatherState.locationName.length > 0 ? WeatherState.locationName : "Weather"
                elide: Text.ElideRight
            }

            // Weather SVGs carry embedded colors — render without overlay
            Image {
                id: heroIcon

                anchors.top: locationLabel.bottom
                anchors.topMargin: StyleTokens.space4
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
                anchors.leftMargin: StyleTokens.space8
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
                // Optical alignment for the temperature glyph; intentionally off-scale.
                anchors.leftMargin: 9
                anchors.right: parent.right
                anchors.rightMargin: root.padH
                anchors.top: heroTemp.bottom
                anchors.topMargin: -StyleTokens.space2
                text: WeatherState.description
                color: Colors.base05
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
                elide: Text.ElideRight
            }

        }

        PopoverSeparator {
            width: parent.width
        }

        // Stats row: FEELS / HUMIDITY / WIND in equal thirds
        Item {
            width: parent.width
            height: StylePopover.weatherStatsHeight

            Row {
                anchors.fill: parent

                Repeater {
                    model: [
                        { label: "Feels", value: WeatherState.feelsLike },
                        { label: "Humidity", value: WeatherState.humidity },
                        { label: "Wind", value: WeatherState.wind }
                    ]

                    Item {
                        required property var modelData

                        width: parent.width / 3
                        height: parent.height

                        EyebrowLabel {
                            id: statLabel

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            // Optical baseline correction for the weather mark; intentionally off-scale.
                            anchors.topMargin: 11
                            text: modelData.label
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: statLabel.bottom
                            anchors.topMargin: StyleTokens.space4
                            width: parent.width - 8
                            text: modelData.value
                            color: Colors.base05
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeMd
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                    }

                }

            }

        }

        PopoverSeparator {
            width: parent.width
        }

        // Forecast axis header. Every row's bar is drawn against one shared
        // scale, which is invisible without this: the two figures sit exactly
        // on the ends of the track below, so the bars read as positions on a
        // range rather than as free-floating widths.
        Item {
            width: parent.width
            height: StylePopover.sectionHeight
            visible: WeatherState.forecast.length > 0

            EyebrowLabel {
                anchors.left: parent.left
                anchors.leftMargin: root.padH
                anchors.verticalCenter: parent.verticalCenter
                text: "Forecast"
            }

            Text {
                x: root.trackLeft - width / 2
                anchors.verticalCenter: parent.verticalCenter
                text: root.degreeLabel(root.weekMin)
                color: Colors.base04
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeXs
            }

            // Hairline spanning the exact width of the bars below, tying the
            // two figures to the track they describe.
            PopoverSeparator {
                x: root.trackLeft + 20
                width: Math.max(0, root.trackWidth - 40)
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                x: root.trackRight - width / 2
                anchors.verticalCenter: parent.verticalCenter
                text: root.degreeLabel(root.weekMax)
                color: Colors.base04
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeXs
            }

        }

        // Forecast rows: day label + icon + temperature range bar
        Repeater {
            id: forecastRepeater

            model: WeatherState.forecast

            Item {
                id: forecastRow

                required property var modelData

                readonly property bool isToday: modelData.date === root.todayDate

                width: root.popoverWidth
                height: StylePopover.forecastRowHeight

                Text {
                    x: root.padH
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.dayLabelWidth
                    text: root.shortDayLabel(forecastRow.modelData.date)
                    color: Colors.base05
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeSm
                    font.weight: forecastRow.isToday ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }

                // Weather SVGs carry embedded colors
                Image {
                    x: root.padH + root.dayLabelWidth + root.columnGap
                    anchors.verticalCenter: parent.verticalCenter
                    source: IconRegistry.weatherIcon(forecastRow.modelData.icon)
                    width: root.forecastIconSize
                    height: root.forecastIconSize
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(root.forecastIconSize, root.forecastIconSize)
                }

                Text {
                    x: root.minLabelX
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.tempLabelWidth
                    text: root.degreeLabel(forecastRow.modelData.minTemp)
                    color: Colors.base04
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeSm
                    horizontalAlignment: Text.AlignRight
                }

                // Track spans the whole forecast range; the fill is this day's slice of it
                Rectangle {
                    id: barTrack

                    x: root.trackLeft
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.trackWidth
                    height: StylePopover.forecastBarHeight
                    radius: StylePopover.forecastBarRadius
                    color: Qt.rgba(Colors.base04.r, Colors.base04.g, Colors.base04.b, 0.15)

                    readonly property real fillStart: root.normalizeTemp(forecastRow.modelData.minTemp)
                    readonly property real fillEnd: root.normalizeTemp(forecastRow.modelData.maxTemp)
                    readonly property bool hasRange: forecastRow.modelData.minTemp !== null && forecastRow.modelData.maxTemp !== null

                    Rectangle {
                        x: barTrack.fillStart * barTrack.width
                        width: Math.max(0, (barTrack.fillEnd - barTrack.fillStart) * barTrack.width)
                        height: parent.height
                        radius: parent.radius
                        visible: barTrack.hasRange

                        // Cool-to-warm across the segment: on a base16 palette
                        // cyan and red are the cold and hot slots, so this still
                        // reads correctly whatever matugen generates.
                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop { position: 0; color: Colors.base0C }
                            GradientStop { position: 1; color: Colors.base08 }
                        }

                    }

                    // "You are here" — current temperature on today's row only.
                    // Overhanging the bar on both sides is what makes it read as
                    // sitting on top; no ring is needed to separate it, which
                    // avoids stroking a shape this small.
                    Rectangle {
                        readonly property real marker: root.normalizeTemp(WeatherState.currentTemp)

                        visible: forecastRow.isToday && !isNaN(WeatherState.currentTemp) && barTrack.hasRange
                        x: marker * barTrack.width - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: StylePopover.forecastMarkerWidth
                        height: StylePopover.forecastMarkerHeight
                        radius: width / 2
                        antialiasing: true
                        color: Colors.base05
                    }

                }

                Text {
                    x: root.trackRight + root.columnGap
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.tempLabelWidth
                    text: root.degreeLabel(forecastRow.modelData.maxTemp)
                    color: Colors.base05
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeSm
                }

            }

        }

        }

        Text {
            anchors.centerIn: parent
            text: "Loading weather…"
            color: Colors.base04
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeSm
            opacity: root.active && !WeatherState.hasData ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: StyleTokens.easeDurationFast
                    easing.type: StyleTokens.easeStandard
                }
            }
        }
    }

}
