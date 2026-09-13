pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || ShellActions.homePath + "/.config") + "/clipse"
    property string historyPath: configDir + "/clipboard_history.json"
    property var entries: []
    property string error: ""
    readonly property bool busy: copyProcess.running
    signal toggleRequested(var screen)
    signal copied()

    function toggle() {
        toggleRequested(ShellActions.focusedScreen())
    }

    function resolvePath(path) {
        const expanded = String(path).replace(/^~/, ShellActions.homePath)
            .replace(/\$\{([^}]+)\}|\$([A-Za-z_][A-Za-z0-9_]*)/g,
                (_, braced, plain) => Quickshell.env(braced || plain))
        return expanded.startsWith("/") ? expanded : configDir + "/" + expanded
    }

    function refresh() {
        error = ""
        configFile.reload()
        historyFile.reload()
    }

    function readHistory() {
        try {
            const data = JSON.parse(historyFile.text()).clipboardHistory
            if (!Array.isArray(data))
                throw new Error("Invalid history")
            entries = data.filter(entry => typeof entry.value === "string")
                .map(entry => ({ value: entry.value, recorded: entry.recorded, pinned: entry.pinned,
                    filePath: entry.filePath === "null" ? "" : (entry.filePath || "") }))
                .sort((a, b) => String(b.recorded).localeCompare(String(a.recorded)))
            error = ""
        } catch (_) {
            error = "Could not read clipboard history"
        }
    }

    function copy(entry) {
        if (!entry || busy)
            return
        error = ""
        copyProcess.payload = entry.filePath ? "" : entry.value
        copyProcess.stdinEnabled = !entry.filePath
        copyProcess.command = entry.filePath
            ? ["sh", "-c", 'exec wl-copy < "$1"', "clipboard-image", resolvePath(entry.filePath)]
            : ["wl-copy", "--type", "text/plain;charset=utf-8"]
        copyProcess.running = true
    }

    FileView {
        id: configFile
        path: root.configDir + "/config.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.historyPath = root.resolvePath(JSON.parse(text()).historyFile || "clipboard_history.json")
            } catch (_) {}
        }
    }

    FileView {
        id: historyFile
        path: root.historyPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.readHistory()
        onLoadFailed: {
            root.entries = []
            root.error = "Clipboard history is unavailable"
        }
    }

    Process {
        id: copyProcess
        property string payload: ""
        onStarted: {
            if (stdinEnabled) {
                write(payload)
                stdinEnabled = false
            }
            payload = ""
        }
        onExited: (exitCode) => {
            if (exitCode === 0)
                root.copied()
            else
                root.error = "Could not copy this entry"
        }
    }
}
