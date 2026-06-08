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
