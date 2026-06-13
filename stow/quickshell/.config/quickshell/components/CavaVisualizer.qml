import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.config

Row {
    id: root

    property bool enabled: true
    property bool active: false

    readonly property int displayBars: Style.cavaDisplayBars
    readonly property int analyzeBars: Style.cavaAnalyzeBars
    readonly property int barWidth: Style.cavaBarWidth
    readonly property int barHeight: Style.cavaBarHeight
    readonly property int barSpacing: Style.cavaSpacing
    readonly property string cavaConfig: `
[general]
bars = ${analyzeBars}
framerate = ${Style.cavaFramerate}

[input]
method = "pulse"

[output]
method = "raw"
data_format = "ascii"
ascii_max_range = ${Style.cavaAsciiMaxRange}
channels = mono
mono_option = average

[smoothing]
monstercat = ${Style.cavaMonstercat ? 1 : 0}
noise_reduction = ${Style.cavaNoiseReduction}
`

    spacing: barSpacing
    height: barHeight
    width: (displayBars * barWidth) + ((displayBars - 1) * barSpacing)

    onActiveChanged: {
        if (!active)
            resetBars()
    }

    onDisplayBarsChanged: rebuildBarsModel()

    Component.onCompleted: rebuildBarsModel()

    ListModel {
        id: barsModel
    }

    Process {
        id: cavaProcess

        command: ["sh", "-c", "printf '%s' \"$CAVA_CONFIG\" | cava -p /dev/stdin"]
        environment: ({ CAVA_CONFIG: root.cavaConfig })
        running: root.enabled && root.visible

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (!root.active)
                    return

                const values = data.trim().split(";").map(Number).filter(v => !Number.isNaN(v))
                if (values.length < root.analyzeBars)
                    return

                const displayValues = root.mapToDisplay(values.slice(0, root.analyzeBars))
                for (let i = 0; i < root.displayBars; i++)
                    barsModel.setProperty(i, "barValue", root.normalize(displayValues[i]))
            }
        }
    }

    Repeater {
        model: barsModel

        Item {
            required property real barValue

            width: root.barWidth
            height: root.barHeight

            Rectangle {
                anchors.centerIn: parent
                width: root.barWidth
                height: Math.max(barValue, Style.cavaSilenceThreshold)
                radius: Style.radiusMd
                color: Colors.base04
                opacity: root.active ? 1 : Style.cavaInactiveOpacity

                Behavior on height {
                    NumberAnimation {
                        duration: Style.cavaAnimationDuration
                        easing.type: Style.cavaEasingCurve(Style.cavaEasing)
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Style.easeDurationNormal
                        easing.type: Style.cavaEasingCurve(Style.cavaEasing)
                    }
                }
            }
        }
    }

    function rebuildBarsModel() {
        barsModel.clear()

        for (let i = 0; i < displayBars; i++)
            barsModel.append({ barValue: 0 })
    }

    function resetBars() {
        for (let i = 0; i < barsModel.count; i++)
            barsModel.setProperty(i, "barValue", 0)
    }

    function averageRange(values, start, end) {
        const from = Math.max(0, Math.min(start, values.length))
        const to = Math.max(from + 1, Math.min(end, values.length))
        let sum = 0

        for (let i = from; i < to; i++)
            sum += values[i]

        return sum / (to - from)
    }

    function mapToDisplay(values) {
        if (displayBars === analyzeBars)
            return values.slice(0, displayBars)

        const bucketSize = values.length / displayBars
        const mapped = []

        for (let i = 0; i < displayBars; i++) {
            const start = Math.floor(i * bucketSize)
            const end = Math.floor((i + 1) * bucketSize)
            mapped.push(averageRange(values, start, end))
        }

        return mapped
    }

    function normalize(value) {
        if (value < Style.cavaSilenceThreshold)
            return 0

        const usableHeight = barHeight - Style.cavaSilenceThreshold
        const level = Math.min(value / Style.cavaAsciiMaxRange, 1) * Style.cavaMaxFill
        const barValue = Style.cavaSilenceThreshold + (level * usableHeight)

        if (barValue < Style.cavaSnapThreshold)
            return Style.cavaSnapHeight

        return barValue
    }
}
