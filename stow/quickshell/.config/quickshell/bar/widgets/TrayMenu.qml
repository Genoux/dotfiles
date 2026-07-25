import QtQuick
import Quickshell
import qs
import qs.components
import qs.config

PopoverPanel {
    id: root

    property var trayItem: null

    signal closeRequested()

    QsMenuOpener {
        id: opener

        menu: root.trayItem ? root.trayItem.menu : null
    }

    Column {
        spacing: 0
        width: StylePopover.panelWidth

        Repeater {
            model: opener.children

            PopoverAction {
                required property var modelData

                width: StylePopover.panelWidth
                label: modelData.isSeparator ? "" : modelData.text
                separator: modelData.isSeparator
                actionEnabled: modelData.enabled
                // Submenu entries rendered flat — prefix signals nested content
                onActivated: {
                    modelData.triggered()
                    root.closeRequested()
                }
            }

        }

    }

}
