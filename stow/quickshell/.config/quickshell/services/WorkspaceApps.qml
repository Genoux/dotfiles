pragma Singleton

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import qs.config

// Which windows a workspace holds, and the icon each one is shown by. Shared by
// the wide bar's workspace pills and the island's workspace dots.
Singleton {
    function windowsOf(workspace) {
        if (!workspace || !workspace.toplevels || !workspace.toplevels.values)
            return []

        return workspace.toplevels.values.filter((toplevel) => {
            return toplevel && toplevel.workspace && toplevel.workspace.id === workspace.id
        })
    }

    function normalizedTokens(values) {
        const seen = {}
        const tokens = []
        const genericTokens = new Set(["chrome", "chromium", "default"])

        for (const value of values) {
            const normalized = String(value || "").toLowerCase().trim()
            const parts = [normalized].concat(normalized.split(/[._\s-]+/))

            for (const token of parts) {
                if (token.length <= 2 || genericTokens.has(token) || seen[token])
                    continue

                seen[token] = true
                tokens.push(token)
            }
        }

        return tokens
    }

    function trayItemForToplevel(toplevel) {
        if (!toplevel)
            return null

        const ipc = toplevel.lastIpcObject || {}
        // Class only, for the reason spelled out in TrayFocus: a window title is
        // content, so matching it against a tray item's name lends one app's
        // icon to any window that mentions it. Without a tray match this falls
        // through to IconRegistry below, which is the ordinary path anyway.
        const windowTokens = normalizedTokens([
            IconRegistry.className(toplevel),
            ipc.initialClass
        ])

        if (!windowTokens.length)
            return null

        return SystemTray.items.values.find((item) => {
            const trayTokens = normalizedTokens([item.id, item.title, item.tooltipTitle])
            return windowTokens.some((windowToken) => {
                return trayTokens.some((trayToken) => {
                    return windowToken === trayToken
                        || windowToken.includes(trayToken)
                        || trayToken.includes(windowToken)
                })
            })
        }) || null
    }

    function iconFor(toplevel) {
        const trayItem = trayItemForToplevel(toplevel)
        if (trayItem)
            return trayItem.icon

        return IconRegistry.source(IconRegistry.iconNameForToplevel(toplevel))
    }
}
