import QtQuick
import Quickshell
import qs.components
import qs.config

// One level of a tray menu: its rows, and the submenu window of whichever row
// is open. TrayMenu hosts the first level; TrayMenuSubmenu hosts the rest.
Item {
    id: rows

    property var menu: null
    property bool active: false
    property var screen: null
    // The window this level sits in, in screen coordinates.
    property real originX: 0
    property real originY: 0

    readonly property real panelWidth: menuColumn.width + StylePopover.padding * 2
    // A submenu's rows arrive over DBus after it opens; until they do, its
    // window would flash empty.
    readonly property bool populated: opener.children.values.length > 0

    property var openEntry: null
    property var hoveredEntry: null
    property var pendingEntry: null

    signal closeRequested()

    function select(entry) {
        openTimer.stop();
        openEntry = entry;
    }

    function cancelPending() {
        openTimer.stop();
    }

    function hoverRow(entry) {
        hoveredEntry = entry;
        pendingEntry = entry.hasChildren && entry.enabled ? entry : null;
        if (pendingEntry === openEntry)
            openTimer.stop();
        else
            openTimer.restart();
    }

    function releaseRow(entry) {
        if (hoveredEntry === entry)
            hoveredEntry = null;
    }

    onActiveChanged: {
        if (!active) {
            openTimer.stop();
            openEntry = null;
        }
    }

    implicitWidth: menuColumn.width
    implicitHeight: menuColumn.implicitHeight
    width: menuColumn.width

    QsMenuOpener {
        id: opener

        menu: rows.menu
    }

    Timer {
        id: openTimer

        interval: StylePopover.contextMenuSubmenuDelay
        onTriggered: rows.openEntry = rows.pendingEntry
    }

    SlidingHighlight {
        run: menuColumn
        slides: false
    }

    Column {
        id: menuColumn

        // implicitWidth is the widest entry's natural width (separators report
        // 0), clamped so one long label can't stretch the menu across the bar
        // and a menu of short verbs still has a sane minimum.
        width: Math.max(StylePopover.contextMenuMinWidth, Math.min(implicitWidth, StylePopover.contextMenuMaxWidth))
        spacing: 0

        Repeater {
            model: rows.menu ? opener.children : null

            PopoverAction {
                id: row

                required property var modelData
                readonly property var level: rows

                width: menuColumn.width
                rowHeight: StylePopover.contextMenuRowHeight
                paddingH: StylePopover.contextMenuPaddingH
                label: modelData.isSeparator ? "" : (modelData.checkState === Qt.Checked ? "✓ " : "") + modelData.text + (modelData.hasChildren ? " ›" : "")
                separator: modelData.isSeparator
                actionEnabled: modelData.enabled
                pinned: rows.openEntry === modelData && rows.hoveredEntry === null
                onActivated: {
                    if (modelData.hasChildren) {
                        rows.select(modelData);
                        return;
                    }
                    modelData.triggered();
                    rows.closeRequested();
                }

                HoverHandler {
                    onHoveredChanged: hovered ? rows.hoverRow(row.modelData) : rows.releaseRow(row.modelData)
                }

                // Loaded per open rather than kept: a fresh opener re-asks the
                // app for the submenu, and closing a level tears down its own.
                Loader {
                    active: rows.openEntry === row.modelData
                    source: "TrayMenuSubmenu.qml"
                    onLoaded: {
                        item.row = row;
                        item.closeRequested.connect(rows.closeRequested);
                    }
                }
            }
        }
    }
}
