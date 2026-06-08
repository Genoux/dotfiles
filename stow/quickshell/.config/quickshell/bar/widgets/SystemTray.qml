import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.components
import qs.services

Row {
    id: root

    visible: SystemTray.items.values.length > 0
    spacing: 2

    Repeater {
        model: SystemTray.items

        IconButton {
            required property var modelData

            iconSource: modelData.icon
            iconSize: 12
            interactive: true

            onClicked: (mouse) => {
                if (mouse.button === Qt.MiddleButton) {
                    modelData.secondaryActivate()
                    return
                }

                TrayFocus.activate(modelData)
            }
        }
    }
}
