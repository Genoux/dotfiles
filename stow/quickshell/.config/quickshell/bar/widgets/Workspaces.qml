import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.config
import qs.components
Row {
    id: root

    property var hyprMonitor

    spacing: 2

    function isNormalWorkspaceEvent(event) {
        if (event.name === "workspace") {
            const name = event.data
            return name.length > 0 && !name.startsWith("special:")
        }

        if (event.name === "workspacev2") {
            const separator = event.data.indexOf(",")
            if (separator < 0) {
                return false
            }

            const id = Number.parseInt(event.data.slice(0, separator), 10)
            const name = event.data.slice(separator + 1)
            return id > 0 && !name.startsWith("special:")
        }

        return false
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (!root.isNormalWorkspaceEvent(event)) {
                return
            }

            Launchers.closeVisibleSpecial()
        }
    }

    Repeater {
        model: Hyprland.workspaces.values.filter((workspace) => workspace.id > 0 && (!root.hyprMonitor || workspace.monitor === root.hyprMonitor))

        Pill {
            required property var modelData

            text: modelData.active ? "●" : modelData.id
            foreground: modelData.focused ? Colors.base05 : Colors.base04
            background: Style.transparent
            hoverBackground: Style.alphaLight
            width: 22
            horizontalPadding: 4
            fontSize: 12
            interactive: true
            onClicked: Launchers.switchWorkspace(modelData.id)

            Behavior on fontSize {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }
}
