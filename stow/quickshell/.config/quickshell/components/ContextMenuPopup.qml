import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services

// Host for a system-style context menu raised from a bar item — the tray's
// right-click menu, not a bar widget panel.
//
// It deliberately does NOT reuse BarPopover. A widget panel is a piece of the
// shell's own UI: it centres on its widget and springs up from the bar.
// A context menu belongs to the application that raised it and should behave
// the way every other menu on the desktop does: pinned to the edge of the item
// that spawned it, appearing at once with no travel, and never animating into
// or out of an unrelated panel.
//
// It stays exclusive with widget panels via PopoverCoordinator, so a menu and
// the calendar are never open together.
Item {
    id: root

    required property var barWindow
    required property Item anchorItem

    property bool open: false
    default property alias content: slot.data

    // Root of the panel's own content, so PopoverCoordinator can tell a click
    // inside the open panel from a click on the bar behind it.
    readonly property Item contentRoot: slot

    // Left edge of the spawning item, in screen coordinates. Resolved
    // imperatively for the same reason as BarPopover.centerX: mapToItem is a
    // method call, so as a declarative binding it would latch onto a
    // pre-layout value at construction and never update.
    property real anchorLeft: 0

    readonly property int screenWidth: (root.barWindow && root.barWindow.screen) ? root.barWindow.screen.width : 0

    function resolveAnchor() {
        anchorLeft = anchorItem.mapToItem(null, 0, 0).x;
    }

    function toggle() {
        open = !open;
    }

    onOpenChanged: {
        if (!open) {
            PopoverCoordinator.notifyClosed(root);
            return;
        }

        resolveAnchor();
        PopoverCoordinator.requestOpen(root);
    }

    PanelWindow {
        id: overlay

        screen: root.barWindow ? root.barWindow.screen : null
        visible: root.open
        color: StyleTokens.transparent
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // Must match the ^(quickshell)$ namespace in hypr windowrules.lua — this is what gets layer blur.
        WlrLayershell.namespace: "quickshell"

        implicitWidth: slot.width
        implicitHeight: slot.height

        anchors {
            left: true
            bottom: true
        }

        onVisibleChanged: {
            if (visible)
                root.resolveAnchor();
        }

        // Aligned to the item's left edge rather than centred on it. Clamping
        // to the screen makes it right-align on its own near the far edge,
        // which is what a menu spawned by the last tray icon should do.
        margins {
            // screenWidth is 0 until the bar window resolves. Clamping against
            // it while it is 0 yields a negative bound and slams the menu to
            // x=0, so skip the right-edge clamp until it is known.
            left: {
                const rightLimit = root.screenWidth > 0 ? root.screenWidth - slot.width : root.anchorLeft;
                return Math.round(Math.max(0, Math.min(root.anchorLeft, rightLimit)));
            }
            bottom: (root.barWindow ? root.barWindow.height : 0) + StylePopover.barGap
        }

        HyprlandFocusGrab {
            active: root.open
            windows: [root.barWindow, overlay]
            onCleared: root.open = false
        }

        Item {
            id: slot

            width: childrenRect.width
            height: childrenRect.height
        }

    }

}
