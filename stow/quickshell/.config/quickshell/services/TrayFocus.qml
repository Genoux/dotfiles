pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick
import qs.config

Singleton {
    function activate(item) {
        if (!item)
            return

        if (item.onlyMenu && item.hasMenu) {
            item.secondaryActivate()
            return
        }

        item.activate()
        tryRaiseMprisPlayer(item)
        focusMatchingWindow(item)
    }

    function tryRaiseMprisPlayer(item) {
        for (const player of Mpris.players.values) {
            if (!player?.canRaise || !trayMatchesPlayer(item, player))
                continue
            player.raise()
            return
        }
    }

    function trayMatchesPlayer(item, player) {
        const id = (item.id || "").toLowerCase()
        const itemTitle = (item.title || item.tooltipTitle || "").toLowerCase()
        const identity = (player.identity || "").toLowerCase()
        const desktop = (player.desktopEntry || "").toLowerCase()

        if (identity && (id.includes(identity) || itemTitle.includes(identity) || identity.includes(id)))
            return true
        if (desktop && (id.includes(desktop) || itemTitle.includes(desktop) || desktop.includes(id)))
            return true

        const idSegments = id.split(/[._-]+/).filter(s => s.length > 2)
        return idSegments.some(s => identity.includes(s) || desktop.includes(s))
    }

    function focusMatchingWindow(item) {
        const id = (item.id || "").toLowerCase()
        const title = (item.title || item.tooltipTitle || "").toLowerCase()
        const tokens = [...new Set([
            id,
            ...id.split(/[._-]+/),
            title.slice(0, 24),
        ].filter(t => t && t.length > 2))]

        const match = Hyprland.toplevels.values.find(w => {
            const cls = (w.wayland?.appId || w.lastIpcObject?.class || "").toLowerCase()
            const initialClass = (w.lastIpcObject?.initialClass || "").toLowerCase()
            const wTitle = (w.title || "").toLowerCase()
            return tokens.some(t => cls.includes(t) || initialClass.includes(t) || t.includes(cls) || wTitle.includes(t))
        })

        if (match?.wayland) {
            match.wayland.activate()
            return
        }

        const address = match?.lastIpcObject?.address
        if (address)
            ShellActions.focusWindow(`address:${address}`)
    }
}
