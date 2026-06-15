pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtCore
import QtQuick

Singleton {
    readonly property var tuiExecutables: ["bluetui", "btop", "impala", "wiremix", "fastfetch", "battop"]
    readonly property var localScripts: ["launch-or-focus", "system-screenrecord", "launch-dotfiles-menu"]
    readonly property string homePath: String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace(/^file:\/\//, "")
    readonly property string localBin: homePath + "/.local/bin/"

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

    function runLocalScript(scriptName, extraArgs) {
        const parts = [localBin + scriptName].concat(extraArgs ?? [])
        const command = parts.join(" ")
        console.log(`ShellActions local script: ${command}`)
        Quickshell.execDetached([
            "hyprctl",
            "dispatch",
            `function() hl.dispatch(hl.dsp.exec_cmd(${quoteLuaString(command)})) end`,
        ])
    }

    function run(command) {
        const args = commandArgs(command)
        if (!args.length)
            return

        const executable = String(args[0])
        if (!executable.includes("/") && localScripts.includes(executable)) {
            runLocalScript(executable, args.slice(1))
            return
        }

        Quickshell.execDetached(args)
    }

    function openDotfilesMenu() {
        dispatchLua(`function() require("actions.launchers").openDotfilesManager() end`)
    }

    function switchKeyboardLayout(device) {
        const target = device && String(device).length > 0 ? String(device) : "current"
        Quickshell.execDetached(["hyprctl", "switchxkblayout", target, "next"])
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
            const extraArgs = args.slice(1)
            let expression = `function() require("actions.launchers").launchOrFocus(${quoteLuaString(appId)}, ${quoteLuaString(executable)}, ${quoteLuaString(className)}`
            for (const extra of extraArgs)
                expression += `, ${quoteLuaString(extra)}`
            expression += ") end"
            dispatchLua(expression)
            return
        }

        const match = findToplevel(appId, className)
        if (match?.wayland) {
            match.wayland.activate()
            return
        }

        run(args)
    }

    function focusedScreen() {
        const monitor = Hyprland.focusedMonitor
        if (!monitor)
            return Quickshell.screens[0] ?? null

        return Quickshell.screens.find((candidate) => {
            const hyprMonitor = Hyprland.monitorFor(candidate)
            return hyprMonitor === monitor || hyprMonitor?.name === monitor?.name
        }) ?? Quickshell.screens[0] ?? null
    }

    function quoteLuaString(value) {
        return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`
    }
}
