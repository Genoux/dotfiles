import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.config

Row {
    id: root

    property bool enabled: true
    property bool active: false

    spacing: 2
    height: 12
    width: 18

    onActiveChanged: {
        if (!active) {
            for (let i = 0; i < barsModel.count; i++)
                barsModel.setProperty(i, "barValue", 0)
        }
    }

    ListModel {
        id: barsModel
        ListElement { barValue: 0 }
        ListElement { barValue: 0 }
        ListElement { barValue: 0 }
        ListElement { barValue: 0 }
    }

    Process {
        command: ["cava", "-p", Quickshell.shellPath("assets/cava/config")]
        running: root.enabled && root.visible

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (!root.active)
                    return

                const values = data.trim().split(";").map(Number).filter(v => !Number.isNaN(v)).slice(0, 4)
                if (values.length === 4) {
                    for (let i = 0; i < 4; i++)
                        barsModel.setProperty(i, "barValue", root.normalize(values[i]))
                }
            }
        }
    }

    Repeater {
        model: barsModel

        Item {
            required property int barValue

            width: 3
            height: 12

            Rectangle {
                anchors.centerIn: parent
                width: 3
                height: Math.max(barValue, 2)
                radius: Style.radiusMd
                color: Colors.base04
                opacity: root.active ? 1 : 0.35

                Behavior on height {
                    SmoothedAnimation { velocity: 80 }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Style.easeDurationNormal
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    function normalize(value) {
        if (value < 2)
            return 0
        return Math.min(12, Math.round(2 + (Math.min(value, 1000) / 1000) * 10 * 1.25))
    }
}
