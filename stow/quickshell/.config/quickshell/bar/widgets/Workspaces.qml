import Quickshell.Hyprland
import QtQuick
import qs
import qs.config
import qs.components
Row {
    spacing: 2

    Repeater {
        model: Hyprland.workspaces

        Pill {
            required property var modelData

            visible: modelData.id > 0
            text: modelData.focused ? "●" : modelData.id
            foreground: modelData.focused ? "white" : Colors.base04
            background: Style.transparent
            hoverBackground: Style.alphaLight
            width: 22
            horizontalPadding: 4
            fontSize: 12
            interactive: true
            onClicked: modelData.activate()

            Behavior on fontSize {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }
}
