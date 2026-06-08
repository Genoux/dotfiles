pragma Singleton

import Quickshell
import QtQuick

Singleton {
    function launchOrFocus(appId, command, fallback) {
        const args = [appId, command]
        if (fallback && fallback.length > 0) {
            args.push(fallback)
        }

        Quickshell.execDetached([
            "hyprctl",
            "dispatch",
            `function() require("actions.launchers").launchOrFocus(${args.map(quoteLuaString).join(", ")}) end`,
        ])
    }

    function focusWindow(selector) {
        Quickshell.execDetached([
            "hyprctl",
            "dispatch",
            `function() hl.dsp.focus({ window = ${quoteLuaString(selector)} }) end`,
        ])
    }

    function run(command) {
        Quickshell.execDetached(command)
    }

    function switchWorkspace(workspaceId) {
        Quickshell.execDetached([
            "hyprctl",
            "dispatch",
            `function() package.loaded["actions.workspaces"]=nil; require("actions.workspaces").switch(${workspaceId}) end`,
        ])
    }

    function quoteLuaString(value) {
        return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`
    }
}
