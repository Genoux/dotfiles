pragma Singleton

import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string historyPath: `${ShellActions.stateDir}/launcher-history.json`
    readonly property int maxEntries: 200

    // Launch order, most recent first. Authoritative in memory: the file backs
    // it up, it is not re-read and re-parsed on every lookup.
    property var recentIds: []

    // id -> launch rank. Rebuilt only when the history changes, because the
    // search comparator reaches for it O(n log n) times per keystroke.
    readonly property var recentRanks: {
        const ranks = new Map()
        recentIds.forEach((entryId, index) => ranks.set(entryId, index))
        return ranks
    }

    // id -> { entry, name, haystack }. Rebuilt only when the installed entry set
    // changes; joining and lowercasing every desktop entry per keystroke was
    // the second-largest cost in the filter. Holding the entry here rather than
    // calling DesktopEntries.byId also makes every consumer's binding depend on
    // the entry set: a rescan deletes the old DesktopEntry objects, so a cached
    // array of them left unrefreshed is a segfault the next time a delegate
    // writes modelData.
    readonly property var searchIndex: {
        const index = new Map()
        for (const entry of DesktopEntries.applications.values) {
            index.set(entry.id, {
                entry: entry,
                name: String(entry.name ?? "").toLowerCase(),
                haystack: [
                    entry.name,
                    entry.genericName,
                    entry.comment,
                    entry.id,
                    ...(entry.keywords ?? []),
                    ...(entry.categories ?? []),
                ].join(" ").toLowerCase()
            })
        }
        return index
    }

    function desktopId(entryId) {
        const text = String(entryId ?? "").trim()
        if (!text)
            return ""

        return text.endsWith(".desktop") ? text.slice(0, -".desktop".length) : text
    }

    function parseRecent(text) {
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

            return recent
        } catch (error) {
            return []
        }
    }

    function recentEntries() {
        return recentIds
            // An uninstalled app lingers in history and has no index entry.
            .map((entryId) => searchIndex.get(entryId)?.entry)
            .filter((entry) => !!entry)
    }

    // Tier ahead of recency: an app whose NAME opens with the query outranks
    // one that merely mentions it in a category, however recently that one ran.
    // Matching still spans the whole haystack, only the ordering is tiered.
    function matchTier(entry, terms, normalizedQuery) {
        const indexed = searchIndex.get(entry.id)
        if (!indexed || !terms.every((term) => indexed.haystack.includes(term)))
            return -1

        if (indexed.name.startsWith(normalizedQuery))
            return 0
        if (indexed.name.includes(normalizedQuery))
            return 1
        return 2
    }

    function search(normalizedQuery, limit) {
        const terms = normalizedQuery.split(/\s+/).filter((term) => term.length > 0)
        if (terms.length === 0)
            return recentEntries()

        const matched = []
        for (const entry of DesktopEntries.applications.values) {
            const tier = matchTier(entry, terms, normalizedQuery)
            if (tier < 0)
                continue

            matched.push({
                entry: entry,
                tier: tier,
                rank: recentRanks.get(entry.id) ?? Number.MAX_SAFE_INTEGER
            })
        }

        matched.sort((left, right) => {
            if (left.tier !== right.tier)
                return left.tier - right.tier
            if (left.rank !== right.rank)
                return left.rank - right.rank
            return left.entry.name.localeCompare(right.entry.name)
        })

        return matched.slice(0, limit).map((match) => match.entry)
    }

    function syncFromFile() {
        recentIds = historyFile.loaded ? parseRecent(historyFile.text()) : []
    }

    function record(entry) {
        const id = desktopId(entry?.id)
        if (!id)
            return

        recentIds = [id, ...recentIds.filter((existingId) => existingId !== id)].slice(0, maxEntries)
        if (!historyFile.adapter)
            return

        historyFile.adapter.recent = recentIds
        historyFile.writeAdapter()
    }

    Process {
        id: ensureDir

        command: ["mkdir", "-p", ShellActions.stateDir]
        running: true
    }

    FileView {
        id: historyFile

        path: root.historyPath
        watchChanges: true
        printErrors: false

        onLoadedChanged: root.syncFromFile()
        onFileChanged: {
            reload()
            root.syncFromFile()
        }

        JsonAdapter {
            property list<string> recent: []
        }
    }
}
