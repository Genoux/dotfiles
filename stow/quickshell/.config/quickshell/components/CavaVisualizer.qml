import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.config

Row {
    id: root

    property bool enabled: true
    property bool active: false
    property var targetBars: [0, 0, 0, 0]
    property var currentBars: [0, 0, 0, 0]
    property int barTick: 0

    spacing: 2
    height: 12
    width: 18

    Process {
        command: ["cava", "-p", Quickshell.shellPath("assets/cava/config")]
        running: root.enabled && root.visible

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (!root.active) {
                    root.targetBars = [0, 0, 0, 0]
                    return
                }

                const values = data
                    .trim()
                    .split(";")
                    .map(Number)
                    .filter((value) => !Number.isNaN(value))
                    .slice(0, 4)

                if (values.length === 4) {
                    root.targetBars = values.map((value) => root.normalize(value))
                }
            }
        }
    }

    Timer {
        interval: 17
        running: root.enabled && root.visible
        repeat: true
        onTriggered: {
            root.currentBars = root.currentBars.map((current, index) => {
                const target = root.targetBars[index] ?? 0
                return Math.round(current + (target - current) * 0.35)
            })
            root.barTick++
        }
    }

    Repeater {
        model: 4

        Item {
            required property int index

            width: 3
            height: 12

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: {
                    const _ = root.barTick
                    const barHeight = root.currentBars[index] ?? 0
                    return Math.max(barHeight, 2)
                }
                radius: Style.radiusMd
                color: Colors.base05
                opacity: root.active ? 1 : 0.35
            }
        }
    }

    function normalize(value) {
        if (value < 2) {
            return 0
        }

        const height = 2 + (Math.min(value, 1000) / 1000) * 10 * 1.25
        return Math.min(12, Math.round(height))
    }
}
