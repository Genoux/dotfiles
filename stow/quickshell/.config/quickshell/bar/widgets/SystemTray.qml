import Quickshell.Services.SystemTray
import QtQuick
import qs.components
import qs.config
import qs.services

BarGroup {
    visible: SystemTray.items.values.length > 0

    Row {
        id: trayRow

        spacing: StyleTray.rowSpacing

        Repeater {
            model: SystemTray.items

            Button {
                required property var modelData

                iconSource: modelData.icon
                iconSize: StyleTray.iconSize
                paddingHorizontal: StyleTray.buttonPaddingHorizontal
                paddingVertical: StyleTray.buttonPaddingVertical
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
}
