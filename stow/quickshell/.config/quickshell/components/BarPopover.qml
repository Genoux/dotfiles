import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Shared popover host docked to the bar top edge.
//
// Uses a fullscreen transparent overlay PanelWindow (same pattern as the
// launcher and power menu) instead of an xdg PopupWindow: popup positioner
// geometry is only computed at show time and proved unreliable for docked
// placement, while a layer window gives full control with plain item math.
// Click-away dismissal is the fullscreen MouseArea; the Hyprland layer rule
// for the "quickshell" namespace provides compositor blur behind the panel.
Item {
    id: root

    required property var barWindow
    required property Item anchorItem

    property bool open: false
    default property alias content: slot.data

    // Captured at open time; the bar window spans the full screen width, so
    // widget coordinates in the bar window match overlay coordinates.
    property real _centerX: 0

    onOpenChanged: {
        if (open)
            _centerX = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x
    }

    PanelWindow {
        id: overlay

        screen: root.barWindow ? root.barWindow.screen : null
        visible: root.open
        color: StyleTokens.transparent
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Item {
            id: slot

            width: childrenRect.width
            height: childrenRect.height
            // Floats above the bar with a small gap so the rounded bottom corners show.
            y: overlay.height - (root.barWindow ? root.barWindow.height : 0) - height - StylePopover.barGap
            // Centered on the widget, clamped so the panel never leaves the screen.
            x: Math.round(Math.max(0, Math.min(
                root._centerX - width / 2,
                overlay.width - width
            )))
        }

    }

}
