pragma Singleton

import Quickshell
import QtQuick

// Tracks which BarPopover is currently open. Popovers no longer share a
// fullscreen click-catcher (see BarPopover.qml), so nothing else enforces
// "opening one closes any other" — this does that instead.
//
Singleton {
    property Item current: null

    // The panel still fading out after dismissal. If another panel opens before
    // that fade ends, its outgoing window is unmounted first so two large panel
    // trees never overlap and read as merged content.
    property Item exiting: null

    function notifyExiting(popover, isExiting) {
        if (isExiting)
            exiting = popover;
        else if (exiting === popover)
            exiting = null;
    }

    function requestOpen(popover) {
        const previous = current;

        if (exiting !== null && exiting !== popover)
            exiting.exiting = false;

        // Adopt the new popover *before* closing the old one: the close below
        // re-enters via notifyClosed, which must see that it is no longer
        // current.
        current = popover;

        if (previous !== null && previous !== popover) {
            previous.open = false;
            if (previous.exiting !== undefined)
                previous.exiting = false;
        }
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
    // tray icon — dismisses.
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
    }
}
