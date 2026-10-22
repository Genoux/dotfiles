import QtQuick
import qs.components
import qs.config

// The tray item's own DBus menu, presented as a system context menu: sized to
// its widest entry rather than filling a panel, and tight rows. See
// ContextMenuPopup for why this is not a bar widget panel.
PopoverPanel {
    id: root

    property var trayItem: null
    property var screen: null
    // This window's top-left corner in screen coordinates, for placing submenus.
    property real originX: 0
    property real originY: 0

    signal closeRequested()

    fitContent: true
    radius: StylePopover.contextMenuRadius

    TrayMenuRows {
        menu: root.trayItem ? root.trayItem.menu : null
        active: root.active
        screen: root.screen
        originX: root.originX
        originY: root.originY
        onCloseRequested: root.closeRequested()
    }
}
