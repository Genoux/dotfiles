import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.components
import qs.config
import qs.services

Rectangle {
    id: root

    readonly property real borderOpacity: 0.1
    readonly property real chromeInset: border.width + Style.mediaPadding
    readonly property real innerHeight: height - chromeInset * 2

    visible: SystemTray.items.values.length > 0
    implicitWidth: trayRow.implicitWidth + chromeInset * 2
    implicitHeight: Style.mediaHeight
    height: implicitHeight
    border.width: 1
    border.color: Qt.rgba(Colors.base04.r, Colors.base04.g, Colors.base04.b, borderOpacity)
    radius: Style.radiusMd
    color: Style.transparent

    Row {
        id: trayRow

        anchors.fill: parent
        anchors.margins: root.chromeInset
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
