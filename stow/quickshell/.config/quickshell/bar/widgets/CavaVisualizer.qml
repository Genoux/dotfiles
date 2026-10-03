import Quickshell.Io
import QtQuick
import qs
import qs.config

Row {
    id: root

    property bool enabled: true
    property bool active: false
    property color barColor: Colors.base04
    property int barCount: StyleCava.displayBars
    property int barWidth: StyleCava.barWidth
    property int barHeight: StyleCava.barHeight
    property int barSpacing: StyleCava.spacing

    readonly property string cavaConfig: `
[general]
bars = ${root.barCount}
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

    spacing: barSpacing
    height: barHeight
    width: barCount * barWidth + (barCount - 1) * barSpacing

    onActiveChanged: {
        if (!active)
            resetBars()
    }

    Component.onCompleted: rebuildBarsModel()
    onBarCountChanged: rebuildBarsModel()

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
                if (values.length < root.barCount)
                    return

                const displayValues = values.slice(0, root.barCount)
                for (let i = 0; i < root.barCount; i++)
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
                height: Math.max(barValue, StyleCava.silenceThreshold)
                radius: StyleTokens.radiusMd
                color: root.barColor
                opacity: root.active ? 1 : StyleCava.inactiveOpacity

                Behavior on height {
                    NumberAnimation {
                        duration: StyleCava.animationDuration
                        easing.type: StyleTokens.easeStandard
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: StyleTokens.motionEnterDuration
                        easing.type: StyleTokens.easeFade
                    }
                }
            }
        }
    }

    function rebuildBarsModel() {
        barsModel.clear()

        for (let i = 0; i < root.barCount; i++)
            barsModel.append({ barValue: 0 })
    }

    function resetBars() {
        for (let i = 0; i < barsModel.count; i++)
            barsModel.setProperty(i, "barValue", 0)
    }

    function normalize(value) {
        if (value < StyleCava.silenceThreshold)
            return 0

        const usableHeight = root.barHeight - StyleCava.silenceThreshold
        const level = Math.min(value / StyleCava.asciiMaxRange, 1) * StyleCava.maxFill
        const barValue = StyleCava.silenceThreshold + (level * usableHeight)

        if (barValue < StyleCava.snapThreshold)
            return StyleCava.snapHeight

        return barValue
    }
}
