import QtQuick
import Quickshell
import qs
import qs.components
import qs.config

// The tray item's own DBus menu, presented as a system context menu: sized to
// its widest entry rather than filling a panel, and tight rows. See
// ContextMenuPopup for why this is not a bar widget panel.
PopoverPanel {
    id: root

    property var trayItem: null

    property var submenuPath: []
    onSubmenuPathChanged: root.animatePanel()
    property int menuRevision: 0
    readonly property var currentOpener: {
        const revision = menuRevision;
        return levels.count > 0 ? levels.objectAt(levels.count - 1) : opener;
    }

    onActiveChanged: {
        if (active)
            submenuPath = [];
    }
    onTrayItemChanged: submenuPath = []

    signal closeRequested()

    fitContent: true

    QsMenuOpener {
        id: opener

        menu: root.trayItem ? root.trayItem.menu : null
    }

    Instantiator {
        id: levels

        model: ScriptModel { values: root.submenuPath }
        delegate: QsMenuOpener {
            required property var modelData
            menu: modelData
        }
        onObjectAdded: root.menuRevision++
        onObjectRemoved: root.menuRevision++
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

        PopoverAction {
            visible: root.submenuPath.length > 0
            width: menuColumn.width
            rowHeight: StylePopover.contextMenuRowHeight
            paddingH: StylePopover.contextMenuPaddingH
            label: "‹ Back"
            onActivated: root.submenuPath = root.submenuPath.slice(0, -1)
        }

        Repeater {
            model: root.currentOpener ? root.currentOpener.children : null

            PopoverAction {
                required property var modelData

                width: menuColumn.width
                rowHeight: StylePopover.contextMenuRowHeight
                paddingH: StylePopover.contextMenuPaddingH
                label: modelData.isSeparator ? "" : (modelData.checkState === Qt.Checked ? "✓ " : "") + modelData.text + (modelData.hasChildren ? " ›" : "")
                separator: modelData.isSeparator
                actionEnabled: modelData.enabled
                onActivated: {
                    if (modelData.hasChildren) {
                        root.submenuPath = root.submenuPath.concat([modelData]);
                        return;
                    }
                    modelData.triggered()
                    root.closeRequested()
                }
            }

        }

    }

}
