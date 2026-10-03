pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root

    signal pageRequested(string pageId, var targetScreen, bool toggle)
    signal closeRequested()

    // The island stretched into a full-width bar.
    readonly property bool wide: persisted.wide
    // Notifications arrive in the island while it is a floating pill; the wide
    // bar keeps the corner toasts.
    readonly property bool islandAlerts: !wide

    function setWide(value) {
        if (persisted.wide === value)
            return;

        persisted.wide = value;
        stateFile.writeAdapter();
    }

    function toggleWide() {
        setWide(!wide);
    }

    function requestPage(pageId, targetScreen = ShellActions.focusedScreen()) {
        pageRequested(pageId, targetScreen, false);
    }

    function togglePage(pageId, targetScreen = ShellActions.focusedScreen()) {
        pageRequested(pageId, targetScreen, true);
    }

    Process {
        command: ["mkdir", "-p", ShellActions.stateDir]
        running: true
    }

    // Read in place, not preloaded: the choice decides the island's first shape,
    // so it has to be known before the first frame rather than flashing the pill.
    FileView {
        id: stateFile

        path: `${ShellActions.stateDir}/layout.json`
        blockLoading: true
        printErrors: false

        JsonAdapter {
            id: persisted

            property bool wide: false
        }
    }
}
