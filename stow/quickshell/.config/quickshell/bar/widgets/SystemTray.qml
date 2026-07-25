import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import qs.components
import qs.config
import qs.services

BarGroup {
    required property var barWindow

    visible: SystemTray.items.values.length > 0

    Row {
        id: trayRow

        spacing: StyleTray.rowSpacing

        Repeater {
            model: SystemTray.items

            Item {
                id: trayDelegate

                required property var modelData

                width: btn.width
                height: btn.height
                implicitWidth: btn.implicitWidth
                implicitHeight: btn.implicitHeight

                Button {
                    id: btn

                    iconSource: trayDelegate.modelData.icon
                    iconSize: StyleTray.iconSize
                    paddingHorizontal: StyleTray.buttonPaddingHorizontal
                    paddingVertical: StyleTray.buttonPaddingVertical
                    interactive: true
                    active: trayPopover.open

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            if (trayDelegate.modelData.hasMenu) {
                                trayPopover.open = !trayPopover.open
                            } else {
                                trayDelegate.modelData.secondaryActivate()
                            }
                            return
                        }
                        if (mouse.button === Qt.MiddleButton) {
                            trayDelegate.modelData.secondaryActivate()
                            return
                        }
                        TrayFocus.activate(trayDelegate.modelData)
                    }
                }

                BarPopover {
                    id: trayPopover

                    barWindow: barWindow
                    anchorItem: btn

                    TrayMenu {
                        active: trayPopover.open
                        trayItem: trayDelegate.modelData
                        onCloseRequested: trayPopover.open = false
                    }
                }
            }
        }
    }
}
