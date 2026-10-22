import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The submenu window of one row, beside the level that owns that row. A plain
// Item because Loader cannot host a bare window; `row` is set once, on load.
Item {
    id: root

    property Item row: null

    readonly property var parentLevel: row ? row.level : null
    readonly property bool ready: parentLevel !== null && submenuRows.populated

    property real windowLeft: 0
    property real windowTop: 0

    signal closeRequested()

    // Imperative, as ContextMenuPopup.resolveAnchor is: mapToItem is a method
    // call, so a declarative binding would latch a pre-layout position.
    function place() {
        const screen = parentLevel.screen;
        if (!screen)
            return;

        const overlap = StylePopover.contextMenuSubmenuOverlap;
        const gap = StylePopover.screenEdgeGap;
        const rowTop = row.mapToItem(null, 0, 0).y;
        const rightEdge = parentLevel.originX + parentLevel.panelWidth - overlap;
        const fitsRight = rightEdge + panel.width <= screen.width - gap;
        const left = fitsRight ? rightEdge : parentLevel.originX + overlap - panel.width;
        const top = parentLevel.originY + rowTop - StylePopover.padding;

        windowLeft = Math.round(Math.max(0, left));
        windowTop = Math.round(Math.max(gap, Math.min(top, screen.height - gap - panel.height)));
    }

    onReadyChanged: {
        if (ready)
            place();
    }

    Connections {
        target: panel
        enabled: root.ready

        function onWidthChanged() {
            root.place();
        }

        function onHeightChanged() {
            root.place();
        }
    }

    PanelWindow {
        id: window

        screen: root.parentLevel ? root.parentLevel.screen : null
        visible: root.ready
        color: StyleTokens.transparent
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-popover"

        implicitWidth: panel.width
        implicitHeight: panel.height

        anchors {
            left: true
            top: true
        }

        margins {
            left: root.windowLeft
            top: root.windowTop
        }

        // The context menu's focus grab is exclusive: a window outside its list
        // gets no pointer events at all.
        onVisibleChanged: PopoverCoordinator.registerGrabPassthrough(window, visible)
        Component.onDestruction: PopoverCoordinator.registerGrabPassthrough(window, false)

        // Reaching the submenu settles a hover that was about to swap it away.
        HoverHandler {
            onHoveredChanged: {
                if (hovered && root.parentLevel)
                    root.parentLevel.cancelPending();
            }
        }

        PopoverPanel {
            id: panel

            active: true
            fitContent: true
            radius: StylePopover.contextMenuRadius

            TrayMenuRows {
                id: submenuRows

                menu: root.row ? root.row.modelData : null
                active: root.parentLevel ? root.parentLevel.active : false
                screen: root.parentLevel ? root.parentLevel.screen : null
                originX: root.windowLeft
                originY: root.windowTop
                onCloseRequested: root.closeRequested()
            }
        }
    }
}
