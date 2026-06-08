pragma Singleton

import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

Singleton {
    id: root

    readonly property string historyPath: `${StandardPaths.writableLocation(StandardPaths.HomeLocation)}/.local/state/quickshell/launcher-history.json`
    readonly property int maxEntries: 200
    property int revision: 0

    function localPath(value) {
        const text = String(value ?? "")
        return text.startsWith("file://") ? text.slice(7) : text
    }

    function desktopId(entryId) {
        const text = String(entryId ?? "").trim()
        if (!text)
            return ""

        return text.endsWith(".desktop") ? text.slice(0, -".desktop".length) : text
    }

    function parseDocument(text) {
        try {
            const data = JSON.parse(String(text || "{}"))
            const seen = new Set()
            const recent = []

            if (Array.isArray(data.recent)) {
                for (const entryId of data.recent) {
                    const id = desktopId(entryId)
                    if (!id || seen.has(id))
                        continue

                    seen.add(id)
                    recent.push(id)
                }
            }

            return {
                recent,
                importedLegacyHistory: Boolean(data.importedLegacyHistory || data.migratedFromElephant),
            }
        } catch (error) {
            return {
                recent: [],
                importedLegacyHistory: false,
            }
        }
    }

    function historyDocument() {
        const _ = revision
        if (!historyFile.loaded)
            return { recent: [], importedLegacyHistory: false }

        return parseDocument(historyFile.text())
    }

    function recentIds() {
        return historyDocument().recent
    }

    function recentRank(entryId) {
        const index = recentIds().indexOf(entryId)
        return index < 0 ? Number.MAX_SAFE_INTEGER : index
    }

    function entryForId(entryId) {
        const id = desktopId(entryId)
        if (!id)
            return null

        return DesktopEntries.byId(id)
            ?? DesktopEntries.applications.values.find((entry) => entry.id === id)
            ?? null
    }

    function recentEntries() {
        const _ = revision
        return recentIds()
            .map((entryId) => entryForId(entryId))
            .filter((entry) => entry !== null)
    }

    function sortEntries(entries) {
        const _ = revision
        return [...entries].sort((left, right) => {
            const leftRank = recentRank(left.id)
            const rightRank = recentRank(right.id)
            if (leftRank !== rightRank)
                return leftRank - rightRank
            return left.name.localeCompare(right.name)
        })
    }

    function persistRecent(recent, importedLegacyHistory) {
        if (!historyFile.adapter)
            return

        historyFile.adapter.recent = recent
        historyFile.adapter.importedLegacyHistory = importedLegacyHistory
        historyFile.writeAdapter()
        historyFile.reload()
        revision++
    }

    function record(entry) {
        const id = desktopId(entry?.id)
        if (!id)
            return

        const document = historyDocument()
        const recent = [id, ...document.recent.filter((existingId) => existingId !== id)].slice(0, maxEntries)
        persistRecent(recent, true)
    }

    function tryImportLegacyHistory() {
        if (!historyFile.loaded || historyDocument().importedLegacyHistory)
            return

        importProcess.running = true
    }

    Process {
        id: ensureDir

        command: ["mkdir", "-p", `${StandardPaths.writableLocation(StandardPaths.HomeLocation)}/.local/state/quickshell`]
        running: true
    }

    Process {
        id: importProcess

        command: [
            Quickshell.shellPath("assets/scripts/import-desktop-history.sh"),
            root.localPath(root.historyPath),
        ]

        onExited: {
            historyFile.reload()
            root.revision++
        }
    }

    Timer {
        interval: 300
        running: historyFile.loaded
        repeat: false
        onTriggered: root.tryImportLegacyHistory()
    }

    FileView {
        id: historyFile

        path: root.historyPath
        watchChanges: true
        printErrors: false

        onLoadedChanged: root.revision++
        onFileChanged: {
            reload()
            root.revision++
        }

        JsonAdapter {
            property list<string> recent: []
            property bool importedLegacyHistory: false
        }
    }
}
