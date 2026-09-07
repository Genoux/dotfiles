import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services

Item {
    id: root

    required property var barWindow
    required property Item anchorItem

    // A panel that only shows state never takes the keyboard, so typing keeps
    // going to the focused window. Raise this for the panels that hold a field.
    property bool acceptsKeyboard: false
    // A panel is normally dropped from its button. Raise this for a panel that
    // reads as a destination rather than a control — About this system — and the
    // compositor places it centred instead. Anchoring nothing is what centres a
    // layer surface; the margins below go unused.
    property bool centered: false
    property bool open: false
    property bool exiting: false
    property bool presented: false
    default property alias content: slot.data

    readonly property Item contentRoot: slot
    readonly property Item panelItem: slot.children.length > 0 ? slot.children[0] : null

    property real centerX: 0
    // The button's top edge within the bar window, so the gap below can be
    // measured from the button rather than from the bar's outer edge.
    property real anchorTop: 0

    function resolveCenterX() {
        centerX = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
        anchorTop = anchorItem.mapToItem(null, 0, 0).y;
    }

    function toggle() {
        open = !open;
    }

    // Unmap immediately so a follow-up overlay (slurp, recorder) is not
    // waiting on the panel's dismiss animation.
    function dismissNow() {
        if (open)
            open = false;
        exiting = false;
        presented = false;
    }

    readonly property int screenWidth: (root.barWindow && root.barWindow.screen) ? root.barWindow.screen.width : 0

    // Measured from the BUTTON's top edge, not the bar's. The bar carries its own
    // padding above the button, so a gap measured from the bar's edge silently
    // included that padding — barGap could be taken to 1 and 7px of air would
    // remain, because the token was never in charge of the distance anyone
    // actually sees. Declared `int` because anchorTop is a real: assigning the
    // rounded expression straight to margins.bottom trips a double-to-int warning
    // on every evaluation.
    readonly property int panelBottomMargin: {
        const barHeight = root.barWindow ? root.barWindow.height : 0;
        return Math.round(Math.max(0, barHeight - root.anchorTop + StylePopover.barGap));
    }

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
        onClosed: root.open = false
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.acceptsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-popover"

        implicitWidth: slot.width
        implicitHeight: slot.height

        onVisibleChanged: {
            if (visible)
                root.resolveCenterX();
        }

        anchors {
            left: !root.centered
            bottom: !root.centered
        }

        margins {
            left: {
                const centred = root.centerX - slot.width / 2;
                const gap = StylePopover.screenEdgeGap;
                const limit = root.screenWidth > 0 ? root.screenWidth - slot.width - gap : centred;
                return Math.round(Math.max(gap, Math.min(centred, limit)));
            }
            bottom: root.panelBottomMargin
        }

        Connections {
            target: overlay.contentItem.Window.window
            enabled: root.open && PopoverCoordinator.current === root

            function onFrameSwapped() {
                PopoverCoordinator.notifyPresented(root);
            }
        }

        HyprlandFocusGrab {
            active: root.open && PopoverCoordinator.current === root
            windows: [root.barWindow, overlay]
            onCleared: {
                if (PopoverCoordinator.current === root)
                    root.open = false;
            }
        }

        Item {
            id: slot

            width: childrenRect.width
            height: childrenRect.height
        }
    }
}
