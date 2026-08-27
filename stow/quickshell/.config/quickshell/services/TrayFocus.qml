pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick
import qs.config

Singleton {
    // Callers must route onlyMenu items to the tray popover themselves —
    // this is only reached for items with their own primary action.
    function activate(item) {
        if (!item)
            return

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

        // Matched on class only, never on the window title. A title is content
        // the user controls, so substring-matching a short token against it
        // raises whatever happens to mention the app: a terminal sitting in a
        // directory called flow answered for Flow's tray icon, and a browser
        // tab reading "Discord | web" would answer for Discord. A class is the
        // app's own identity and is the only half of this worth trusting.
        //
        // Classes shorter than three characters are dropped for the same reason
        // the tokens are: `t.includes(cls)` with a two-letter class matches
        // almost everything.
        const match = Hyprland.toplevels.values.find(w => {
            const classes = [w.wayland?.appId, w.lastIpcObject?.class, w.lastIpcObject?.initialClass]
                .map(c => String(c || "").toLowerCase())
                .filter(c => c.length > 2)
            return classes.some(cls => tokens.some(t => cls.includes(t) || t.includes(cls)))
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
