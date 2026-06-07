pragma Singleton

import Quickshell
import Quickshell.Io
import QtCore

Singleton {
    id: root

    readonly property string stateFilePath: `${StandardPaths.writableLocation(StandardPaths.HomeLocation)}/.local/state/dotfiles/updates.state`
    property int revision: 0
    readonly property string rawState: {
        const _ = revision
        return stateFile.loaded ? stateFile.text() : ""
    }
    readonly property bool updatesAvailable: parseValue("UPDATES_AVAILABLE") === "true"
    readonly property int commitCount: Number(parseValue("COMMIT_COUNT")) || 0

    function parseValue(key) {
        const prefix = `${key}=`
        const line = rawState.split("\n").find((candidate) => candidate.startsWith(prefix))
        return line ? line.slice(prefix.length).trim() : ""
    }

    FileView {
        id: stateFile

        path: root.stateFilePath
        watchChanges: true
        printErrors: false

        onLoadedChanged: root.revision++
        onFileChanged: {
            reload()
            root.revision++
        }
    }
}
