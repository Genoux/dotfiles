pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root

    signal pageRequested(string pageId, var targetScreen, bool toggle)
    signal closeRequested()

    readonly property bool island: persisted.island

    // 0 is the bar, 1 is the island. Both surfaces exist while it is between, and
    // each fades by its own share of it, so the switch is one motion rather than
    // one surface being torn down and the other built in the same frame.
    property real progress: persisted.island ? 1 : 0
    readonly property bool barPresent: progress < 1
    readonly property bool islandPresent: progress > 0
    readonly property real barReveal: Math.max(0, Math.min(1, 1 - progress / StyleIsland.barExitShare))
    readonly property real islandReveal: Math.max(0, Math.min(1,
        (progress - StyleIsland.islandEntryStart) / (1 - StyleIsland.islandEntryStart)))

    Behavior on progress {
        NumberAnimation {
            duration: StyleIsland.handoverDuration
            easing.type: StyleTokens.easeStandard
        }
    }

    function setIsland(value) {
        if (persisted.island === value)
            return;

        persisted.island = value;
        stateFile.writeAdapter();
    }

    function toggleIsland() {
        setIsland(!island);
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

    // Read in place, not preloaded: the choice decides which windows exist, so
    // it has to be known before the first frame rather than flashing the bar.
    FileView {
        id: stateFile

        path: `${ShellActions.stateDir}/layout.json`
        blockLoading: true
        printErrors: false

        JsonAdapter {
            id: persisted

            property bool island: false
        }
    }
}
