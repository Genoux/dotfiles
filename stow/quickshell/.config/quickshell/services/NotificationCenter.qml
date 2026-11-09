pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// What arrived while the popups came and went, newest first, and do not
// disturb. Authoritative in memory: the file carries it across restarts and is
// read once.
Singleton {
    id: root

    readonly property string historyPath: `${ShellActions.stateDir}/notification-history.json`
    readonly property int maxEntries: 100
    // The --app-name stow/scripts/.local/bin/system-update-check sends; its
    // notification is the update card, not a row.
    readonly property string systemUpdateApp: "System Update"
    // Notification ids restart at 1 with every server, so a stored id names a
    // live notification only when this run recorded it.
    readonly property string session: String(Date.now())

    property var entries: []
    property bool doNotDisturb: false
    // Nothing is written before the file has been read, or the first
    // notification of a session would overwrite the saved history. A file that
    // exists but cannot be read is never written at all: the session keeps its
    // history in memory and the file stays as it was for someone to look at.
    property bool restored: false
    // A toggle made before the file was read outranks the saved setting.
    property bool doNotDisturbChosen: false

    readonly property var systemUpdate: entries.find((entry) => entry.appName === systemUpdateApp) ?? null
    readonly property var feed: entries.filter((entry) => entry.appName !== systemUpdateApp)
    readonly property bool hasUnseen: entries.some((entry) => !entry.seen)

    signal toggleRequested(var targetScreen)

    function toggle() {
        toggleRequested(ShellActions.focusedScreen())
    }

    // An image-data hint is served from memory and dies with its notification.
    function lastingImage(image) {
        const source = String(image ?? "")
        return source.startsWith("/") || source.startsWith("file://") ? source : ""
    }

    function record(notification) {
        if (!notification || notification.transient)
            return

        const entry = {
            "key": `${session}-${notification.id}`,
            "session": session,
            "id": notification.id,
            "appName": String(notification.appName ?? ""),
            "appIcon": String(notification.appIcon ?? ""),
            "desktopEntry": String(notification.desktopEntry ?? ""),
            "image": lastingImage(notification.image),
            "summary": Notifications.cleanText(notification.summary),
            "body": Notifications.cleanText(notification.body),
            "time": Date.now(),
            "seen": false
        }
        const replacesUpdate = entry.appName === systemUpdateApp
        const kept = replacesUpdate ? entries.filter((existing) => existing.appName !== systemUpdateApp) : entries
        replaceEntries([entry, ...kept].slice(0, maxEntries))
    }

    function remove(removed) {
        const removedKeys = new Set(removed.map((entry) => entry.key))
        replaceEntries(entries.filter((existing) => !removedKeys.has(existing.key)))
    }

    function clear() {
        replaceEntries([])
    }

    function markAllSeen() {
        if (hasUnseen)
            replaceEntries(entries.map((entry) => entry.seen ? entry : Object.assign({}, entry, { "seen": true })))
    }

    function setDoNotDisturb(enabled) {
        doNotDisturb = enabled
        doNotDisturbChosen = true
        save()
    }

    function liveNotification(entry) {
        if (entry?.session !== session)
            return null

        return Notifications.notifications.find((notification) => notification.id === entry.id) ?? null
    }

    // Its own default action while the notification is still up; once it has
    // closed, only its app is left to open.
    function activate(entry) {
        const live = liveNotification(entry)
        Notifications.activate(live ?? entry)
        if (live)
            Notifications.dismiss(live)
        remove([entry])
    }

    // Launched here rather than through the notification's action, which only
    // exists while system-update-check is still waiting on it.
    function runSystemUpdate() {
        clearSystemUpdate()
        ShellActions.run("system-update")
    }

    function clearSystemUpdate() {
        const entry = systemUpdate
        if (!entry)
            return

        const live = liveNotification(entry)
        if (live)
            Notifications.dismiss(live)
        remove([entry])
    }

    function replaceEntries(nextEntries) {
        entries = nextEntries
        save()
    }

    function save() {
        if (restored)
            historyFile.setText(JSON.stringify({ "doNotDisturb": doNotDisturb, "entries": entries }))
    }

    function keepInMemory(reason) {
        console.warn(`NotificationCenter: ${historyPath} ${reason}; this session's history stays in memory and the file is left untouched`)
    }

    function parseHistory(text) {
        try {
            const saved = JSON.parse(text || "{}")
            return saved && typeof saved === "object" ? saved : null
        } catch (error) {
            return null
        }
    }

    function restore(text) {
        if (restored)
            return

        const saved = parseHistory(text)
        if (!saved) {
            keepInMemory("is not valid history JSON")
            return
        }

        const recordedKeys = new Set(entries.map((entry) => entry.key))
        const savedEntries = (Array.isArray(saved.entries) ? saved.entries : [])
            .filter((entry) => entry?.key && !recordedKeys.has(entry.key))
        entries = [...entries, ...savedEntries].slice(0, maxEntries)
        if (!doNotDisturbChosen)
            doNotDisturb = saved.doNotDisturb === true

        restored = true
        save()
    }

    FileView {
        id: historyFile

        path: root.historyPath
        printErrors: false

        onLoaded: root.restore(text())
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound)
                root.restore("")
            else
                root.keepInMemory(`could not be read (FileViewError ${error})`)
        }
    }
}
