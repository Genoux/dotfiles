pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import qs.config

Singleton {
    id: root

    property var pendingItem: null

    function activate(item) {
        if (!item) {
            return
        }

        pendingItem = item
        item.activate()
        tryRaiseMprisPlayer(item)
        clientsProcess.running = true
    }

    function tryRaiseMprisPlayer(item) {
        for (const player of Mpris.players.values) {
            if (!player?.canRaise || !trayMatchesPlayer(item, player)) {
                continue
            }

            player.raise()
            return
        }
    }

    function trayMatchesPlayer(item, player) {
        const id = (item.id || "").toLowerCase()
        const itemTitle = (item.title || item.tooltipTitle || "").toLowerCase()
        const identity = (player.identity || "").toLowerCase()
        const desktop = (player.desktopEntry || "").toLowerCase()

        if (identity && (id.includes(identity) || itemTitle.includes(identity) || identity.includes(id))) {
            return true
        }

        if (desktop && (id.includes(desktop) || itemTitle.includes(desktop) || desktop.includes(id))) {
            return true
        }

        const idSegments = id.split(/[._-]+/).filter((segment) => segment.length > 2)
        return idSegments.some((segment) => identity.includes(segment) || desktop.includes(segment))
    }

    function focusFromClients(clients, item) {
        if (!item || !Array.isArray(clients) || clients.length === 0) {
            return
        }

        const id = (item.id || "").toLowerCase()
        const title = (item.title || item.tooltipTitle || "").toLowerCase()
        const tokens = [...new Set([
            id,
            ...id.split(/[._-]+/),
            title.slice(0, 24),
        ].filter((token) => token && token.length > 2))]

        const match = clients.find((client) => {
            const cls = (client.class || "").toLowerCase()
            const initialClass = (client.initialClass || "").toLowerCase()
            const clientTitle = (client.title || "").toLowerCase()

            return tokens.some((token) => cls.includes(token)
                || initialClass.includes(token)
                || token.includes(cls)
                || clientTitle.includes(token))
        })

        if (match?.address) {
            Launchers.focusWindow(`address:${match.address}`)
        }
    }

    Process {
        id: clientsProcess

        command: ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.focusFromClients(JSON.parse(this.text), root.pendingItem)
                } catch (error) {
                    console.warn("TrayFocus: failed to parse hyprctl clients output", error)
                }

                root.pendingItem = null
            }
        }
    }
}
