import QtQuick
import Quickshell
import qs
import qs.components
import qs.config

// The tray item's own DBus menu, presented as a system context menu: sized to
// its widest entry rather than filling a panel, tight rows, and no spring on
// reveal. See ContextMenuPopup for why this is not a bar widget panel.
PopoverPanel {
    id: root

    property var trayItem: null

    signal closeRequested()

    fitContent: true
    springReveal: false

    QsMenuOpener {
        id: opener

        menu: root.trayItem ? root.trayItem.menu : null
    }

    Column {
        id: menuColumn

        // implicitWidth is the widest entry's natural width (separators report
        // 0), clamped so one long label can't stretch the menu across the bar
        // and a menu of short verbs still has a sane minimum.
        width: Math.max(StylePopover.contextMenuMinWidth, Math.min(implicitWidth, StylePopover.contextMenuMaxWidth))
        topPadding: StylePopover.contextMenuPaddingV
        bottomPadding: StylePopover.contextMenuPaddingV
        spacing: 0

        Repeater {
            model: opener.children

            PopoverAction {
                required property var modelData

                width: menuColumn.width
                rowHeight: StylePopover.contextMenuRowHeight
                paddingH: StylePopover.contextMenuPaddingH
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
