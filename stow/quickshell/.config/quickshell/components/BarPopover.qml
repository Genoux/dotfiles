import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services

// Host for a bar widget's panel. The window remains mapped while the panel's
// OUT animation runs, then unmounts after the visual has fully faded.
Item {
    id: root

    required property var barWindow
    required property Item anchorItem

    // A panel that only shows state never takes the keyboard, so typing keeps
    // going to the focused window. Raise this for the panels that hold a field.
    property bool acceptsKeyboard: false
    property bool open: false
    property bool exiting: false
    property bool presented: false
    default property alias content: slot.data

    readonly property Item contentRoot: slot
    readonly property Item panelItem: slot.children.length > 0 ? slot.children[0] : null

    property real centerX: 0

    function resolveCenterX() {
        centerX = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
    }

    function toggle() {
        open = !open;
    }

    // Unmap immediately so a follow-up overlay (slurp, recorder) is not
    // waiting on the panel's 160ms dismiss animation.
    function dismissNow() {
        if (open)
            open = false;
        exiting = false;
        presented = false;
    }

    readonly property int screenWidth: (root.barWindow && root.barWindow.screen) ? root.barWindow.screen.width : 0

    onExitingChanged: {
        PopoverCoordinator.notifyExiting(root, exiting);
        if (!exiting && !open)
            presented = false;
    }

    onOpenChanged: {
        if (!open) {
            PopoverCoordinator.notifyClosed(root);
            exiting = true;
            return;
        }

        presented = true;
        exiting = false;
        resolveCenterX();
        PopoverCoordinator.requestOpen(root);
    }

    Connections {
        target: root.panelItem
        ignoreUnknownSignals: true

        function onDismissFinished() {
            if (!root.open)
                root.exiting = false;
        }
    }

    PanelWindow {
        id: overlay

        screen: root.barWindow ? root.barWindow.screen : null
        visible: root.presented
        color: StyleTokens.transparent
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.acceptsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        // Must match the ^(quickshell)$ namespace in hypr windowrules.lua — this is what gets layer blur.
        WlrLayershell.namespace: "quickshell"

        implicitWidth: slot.width
        implicitHeight: slot.height

        onVisibleChanged: {
            if (visible)
                root.resolveCenterX();
        }

        anchors {
            left: true
            bottom: true
        }

        margins {
            left: {
                const centred = root.centerX - slot.width / 2;
                const rightLimit = root.screenWidth > 0 ? root.screenWidth - slot.width : centred;
                return Math.round(Math.max(0, Math.min(centred, rightLimit)));
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
