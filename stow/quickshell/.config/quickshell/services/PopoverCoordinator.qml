pragma Singleton

import Quickshell
import QtQuick
import qs.config

// Tracks which BarPopover is currently open. Popovers no longer share a
// fullscreen click-catcher (see BarPopover.qml), so nothing else enforces
// "opening one closes any other" — this does that instead.
//
// It also carries the hand-off position across a swap, so the incoming panel
// can glide from where the outgoing one sat and the pair reads as one panel
// moving along the bar rather than two panels blinking independently.
Singleton {
    property Item current: null

    // Centre of the popover being replaced; NaN on a cold open.
    property real handoffCenterX: NaN
    readonly property bool handingOff: !isNaN(handoffCenterX)

    // Where the most recently closed popover sat. Clicking a second widget
    // while one is open dismisses the first via HyprlandFocusGrab, which fires
    // before the second one opens — so by the time the incoming popover asks
    // what it is replacing, `current` is already null. This remembers the
    // outgoing position just long enough to bridge that gap, which also makes
    // the hand-off work regardless of which of the two events lands first.
    property real recentCenterX: NaN

    // A popover opts out by declaring handoffEligible: false. Tray context
    // menus do — they are still exclusive with everything else, but a menu
    // should never appear to be the calendar sliding across the bar.
    function eligible(popover) {
        return popover !== null && popover.handoffEligible === true;
    }

    function requestOpen(popover) {
        const previous = current;
        const replacing = previous !== null && previous !== popover;

        if (!eligible(popover))
            handoffCenterX = NaN;
        else if (replacing)
            handoffCenterX = eligible(previous) ? previous.centerX : NaN;
        else if (handoffGrace.running)
            handoffCenterX = recentCenterX;
        else
            handoffCenterX = NaN;

        // Adopt the new popover *before* closing the old one: the close below
        // re-enters via notifyClosed, which must see that it is no longer
        // current or it would overwrite the hand-off state we just resolved.
        current = popover;

        if (replacing)
            previous.open = false;
    }

    // Click-away dismissal from bare bar surface; see the MouseArea in Bar.qml.
    function closeCurrent() {
        if (current !== null)
            current.open = false;
    }

    function isDescendantOf(item, ancestor) {
        for (let node = item; node !== null; node = node.parent) {
            if (node === ancestor)
                return true;
        }

        return false;
    }

    // Called by every interactive Button on click. Dismisses the open popover
    // unless the click belongs to it, which is decided structurally rather than
    // by timing:
    //
    //   - the popover's own anchor toggles itself, so leave it alone or the
    //     dismissal here and the toggle there would cancel out and it could
    //     never be closed by clicking its own widget;
    //   - a control *inside* the open panel (the calendar's month chevrons and
    //     Today pill are Buttons) must not dismiss the panel it lives in.
    //
    // Everything else — another widget, a widget with no popover of its own, a
    // tray icon — dismisses. A replacement opening right after still glides,
    // because notifyClosed leaves the hand-off grace running.
    function notifyInteraction(item) {
        if (current === null || current.anchorItem === item)
            return;

        if (isDescendantOf(item, current.contentRoot))
            return;

        current.open = false;
    }

    function notifyClosed(popover) {
        if (current !== popover)
            return;

        current = null;

        // A closing context menu must not seed a hand-off for whatever opens
        // next, or a widget panel would glide out of where the menu stood.
        if (!eligible(popover)) {
            recentCenterX = NaN;
            return;
        }

        recentCenterX = popover.centerX;
        handoffGrace.restart();
    }

    // Only a dismissal that is part of the same click as the next open should
    // count as a hand-off; anything slower is a cold open.
    Timer {
        id: handoffGrace

        interval: StylePopover.handoffGrace
    }
}
