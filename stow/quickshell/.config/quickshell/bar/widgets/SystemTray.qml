import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.components
import qs.config
import qs.services

BarGroup {
    id: root

    visible: SystemTray.items.values.length > 0
    implicitWidth: trayRow.implicitWidth + chromeInset * 2

    Row {
        id: trayRow

        anchors.fill: parent
        spacing: 1

        Repeater {
            model: SystemTray.items

            IconButton {
                required property var modelData

                readonly property real buttonSize: trayRow.height

                iconSource: modelData.icon
                iconSize: Math.max(10, Math.round(buttonSize * 0.55))
                interactive: true
                width: buttonSize
                height: buttonSize

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
