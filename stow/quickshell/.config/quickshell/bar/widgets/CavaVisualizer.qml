import Quickshell.Io
import QtQuick
import qs
import qs.config

Row {
    id: root

    property bool enabled: true
    property bool active: false

    readonly property string cavaConfig: `
[general]
bars = ${StyleCava.analyzeBars}
framerate = ${StyleCava.framerate}

[input]
method = "pulse"

[output]
method = "raw"
data_format = "ascii"
ascii_max_range = ${StyleCava.asciiMaxRange}
channels = mono
mono_option = average

[smoothing]
monstercat = ${StyleCava.monstercat ? 1 : 0}
noise_reduction = ${StyleCava.noiseReduction}
`

    spacing: StyleCava.spacing
    height: StyleCava.barHeight
    width: StyleCava.visualWidth

    onActiveChanged: {
        if (!active)
            resetBars()
    }

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
                if (values.length < StyleCava.analyzeBars)
                    return

                const displayValues = root.mapToDisplay(values.slice(0, StyleCava.analyzeBars))
                for (let i = 0; i < StyleCava.displayBars; i++)
                    barsModel.setProperty(i, "barValue", root.normalize(displayValues[i]))
            }
        }
    }

    Repeater {
        model: barsModel

        Item {
            required property real barValue

            width: StyleCava.barWidth
            height: StyleCava.barHeight

            Rectangle {
                anchors.centerIn: parent
                width: StyleCava.barWidth
                height: Math.max(barValue, StyleCava.silenceThreshold)
                radius: StyleTokens.radiusMd
                color: Colors.base04
                opacity: root.active ? 1 : StyleCava.inactiveOpacity

                Behavior on height {
                    NumberAnimation {
                        duration: StyleCava.animationDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: StyleTokens.easeDurationNormal
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    function rebuildBarsModel() {
        barsModel.clear()

        for (let i = 0; i < StyleCava.displayBars; i++)
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
        if (StyleCava.displayBars === StyleCava.analyzeBars)
            return values.slice(0, StyleCava.displayBars)

        const bucketSize = values.length / StyleCava.displayBars
        const mapped = []

        for (let i = 0; i < StyleCava.displayBars; i++) {
            const start = Math.floor(i * bucketSize)
            const end = Math.floor((i + 1) * bucketSize)
            mapped.push(averageRange(values, start, end))
        }

        return mapped
    }

    function normalize(value) {
        if (value < StyleCava.silenceThreshold)
            return 0

        const usableHeight = StyleCava.barHeight - StyleCava.silenceThreshold
        const level = Math.min(value / StyleCava.asciiMaxRange, 1) * StyleCava.maxFill
        const barValue = StyleCava.silenceThreshold + (level * usableHeight)

        if (barValue < StyleCava.snapThreshold)
            return StyleCava.snapHeight

        return barValue
    }
}
