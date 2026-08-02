import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import qs.components
import qs.config
import qs.services

BarGroup {
    id: root

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
                property bool menuLoaded: false

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
                                trayPopover.toggle()
                            } else {
                                trayDelegate.modelData.secondaryActivate()
                            }
                            return
                        }
                        if (mouse.button === Qt.MiddleButton) {
                            trayDelegate.modelData.secondaryActivate()
                            return
                        }
                        // Items with no primary action of their own — only a menu —
                        // must show it here rather than fall through to activate():
                        // apps that pop their own window on Activate() have no
                        // reliable way to learn our icon's screen position, so it
                        // lands wherever they default to (often top-left of screen).
                        if (trayDelegate.modelData.onlyMenu && trayDelegate.modelData.hasMenu) {
                            trayPopover.toggle()
                            return
                        }
                        TrayFocus.activate(trayDelegate.modelData)
                    }
                }

                ContextMenuPopup {
                    id: trayPopover

                    // Must be qualified: an unqualified `barWindow` here resolves
                    // against the popup's own property of that name, not this
                    // widget's, and silently binds to undefined.
                    barWindow: root.barWindow
                    anchorItem: btn

                    // QsMenuOpener fetches the item's DBus menu as soon as it binds
                    // to trayItem, so build the menu only once first opened rather
                    // than round-tripping DBus for every tray icon at startup.
                    Loader {
                        active: trayDelegate.menuLoaded
                        sourceComponent: menuComponent
                    }
                }

                Connections {
                    target: trayPopover

                    function onOpenChanged() {
                        if (trayPopover.open)
                            trayDelegate.menuLoaded = true;
                    }
                }

                Component {
                    id: menuComponent

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
