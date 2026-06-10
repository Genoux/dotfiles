pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    readonly property var tuiExecutables: ["bluetui", "btop", "impala", "wiremix", "fastfetch", "battop"]

    function normalize(value) {
        return String(value || "").toLowerCase().trim()
    }

    function commandArgs(command) {
        return Array.isArray(command) ? command : String(command).split(/\s+/).filter(Boolean)
    }

    function tokenMatchesField(token, field) {
        if (!token || token.length < 2 || !field || field.length < 2)
            return false
        return field.includes(token) || token.includes(field)
    }

    function findToplevel(appId, fallback) {
        const needles = [appId, fallback].map(normalize).filter(token => token.length > 2)
        if (!needles.length)
            return null

        return Hyprland.toplevels.values.find(toplevel => {
            const cls = normalize(toplevel.wayland?.appId || toplevel.lastIpcObject?.class || toplevel.lastIpcObject?.initialClass)
            const title = normalize(toplevel.title)
            return needles.some(needle => tokenMatchesField(needle, cls) || tokenMatchesField(needle, title))
        }) ?? null
    }

    function run(command) {
        Quickshell.execDetached(commandArgs(command))
    }

    function dispatchLua(expression) {
        Hyprland.dispatch(expression)
    }

    function focusWindow(selector) {
        dispatchLua(`function() hl.dsp.focus({ window = ${quoteLuaString(selector)} }) end`)
    }

    function switchWorkspace(workspace) {
        const id = typeof workspace === "object" ? workspace?.id : Number(workspace)
        if (!Number.isFinite(id))
            return

        dispatchLua(`function() require("actions.workspaces").switch(${id}) end`)
    }

    function launchOrFocus(appId, command, fallback) {
        const className = fallback || appId
        const args = commandArgs(command)
        const executable = args[0] || className

        if (tuiExecutables.includes(executable) || tuiExecutables.includes(normalize(appId))) {
            run(["launch-or-focus", appId, executable, className])
            return
        }

        const match = findToplevel(appId, className)
        if (match?.wayland) {
            match.wayland.activate()
            return
        }

        run(args)
    }

    function quoteLuaString(value) {
        return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`
    }
}
