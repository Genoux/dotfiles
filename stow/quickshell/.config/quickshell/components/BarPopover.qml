import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services

// Host for a bar widget's panel: centred on its widget, springs up from the
// bar, and hands off to sibling panels. Tray menus use ContextMenuPopup.
//
// Dismissal is HyprlandFocusGrab, not a fullscreen click-catcher: one of those
// sits above the bar and swallows clicks meant for other bar widgets. The grab
// treats the bar as inside itself so those clicks still land, which is why
// dismissing on a bar click is PopoverCoordinator's job instead.
//
// x is plain arithmetic, not cross-window mapping: the bar spans the full
// screen width from 0, so widget x equals screen x. y and screen width come
// from the bar window, since this overlay is sized to the panel.
Item {
    id: root

    required property var barWindow
    required property Item anchorItem

    property bool open: false
    default property alias content: slot.data

    // Widget panels hand off to each other; see PopoverCoordinator.
    readonly property bool handoffEligible: true

    // Root of the panel's own content, so PopoverCoordinator can tell a click
    // inside the open panel from a click on the bar behind it.
    readonly property Item contentRoot: slot

    // Resolved imperatively, and deliberately NOT a declarative binding:
    // mapToItem is a method call, so the ancestor positions it walks are never
    // registered as binding dependencies. As a binding it would evaluate once
    // at construction — before the bar's layout has placed anything — and then
    // never update, pinning every popover to the far left.
    //
    // The race that argues for a binding is real though: `visible: root.open`
    // and this handler both react to the same `open` flip, and the window can
    // map from a stale value before the handler runs. Recomputing on the
    // overlay's own onVisibleChanged closes that, since it fires exactly when
    // the window maps, whichever order the two handlers happen to run in.
    // Read by PopoverCoordinator to position a hand-off, so not private.
    property real centerX: 0

    function resolveCenterX() {
        centerX = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
    }

    function toggle() {
        open = !open;
    }

    readonly property int screenWidth: (root.barWindow && root.barWindow.screen) ? root.barWindow.screen.width : 0

    // Displacement while gliding over from the popover this one replaced.
    // Decays to 0, so it only perturbs the resting position mid-swap.
    property real handoffOffset: 0

    onOpenChanged: {
        if (!open) {
            PopoverCoordinator.notifyClosed(root);
            return;
        }

        resolveCenterX();
        PopoverCoordinator.requestOpen(root);

        // requestOpen has just resolved where the outgoing popover sat, if any.
        handoffOffset = PopoverCoordinator.handingOff ? PopoverCoordinator.handoffCenterX - centerX : 0;

        if (handoffOffset !== 0)
            handoffAnimation.restart();
    }

    NumberAnimation {
        id: handoffAnimation

        target: root
        property: "handoffOffset"
        to: 0
        duration: StylePopover.handoffDuration
        easing.type: Easing.OutCubic
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

        implicitWidth: slot.width
        implicitHeight: slot.height

        // Fires exactly when the window maps, so the position is re-resolved
        // from settled layout no matter how the open-handler ordering falls.
        onVisibleChanged: {
            if (visible)
                root.resolveCenterX();
        }

        anchors {
            left: true
            bottom: true
        }

        // Floats above the bar with a small gap so the rounded bottom corners
        // show. Centered on the widget, clamped so the panel never leaves
        // the screen. The hand-off glide is added after the clamp because it
        // is transient — feeding it through would stall the panel against the
        // screen edge partway across.
        margins {
            // screenWidth is 0 until the bar window resolves. Clamping against
            // it while it is 0 yields a negative bound and slams the panel to
            // x=0, so skip the right-edge clamp until it is known.
            left: {
                const centred = root.centerX - slot.width / 2;
                const rightLimit = root.screenWidth > 0 ? root.screenWidth - slot.width : centred;
                return Math.round(Math.max(0, Math.min(centred, rightLimit)) + root.handoffOffset);
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
