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

    function run(command) {
        Quickshell.execDetached(command)
    }

    function quoteLuaString(value) {
        return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`
    }
}
