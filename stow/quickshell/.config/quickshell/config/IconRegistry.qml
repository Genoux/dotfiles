pragma Singleton

import Quickshell
import QtQuick

Singleton {
    function barIcon(domain, name) {
        return Quickshell.shellPath(`assets/icons/${domain}/${name}.svg`)
    }

    function isBarIcon(url) {
        const path = url?.toString?.() ?? String(url ?? "")
        return path.includes("assets/icons/")
    }

    function batteryIcon(percent, charging) {
        const step = Math.min(Math.floor(percent / 10) * 10, 100)
        if (charging && step === 100)
            return barIcon("battery", "charged")
        if (charging)
            return barIcon("battery", `charging-${step}`)
        return barIcon("battery", `${step}`)
    }

    function volumeIcon(level, isMuted, hasSink) {
        if (!hasSink || isMuted)
            return barIcon("audio", "muted")
        if (level > 0.66)
            return barIcon("audio", "high")
        if (level > 0.33)
            return barIcon("audio", "medium")
        return barIcon("audio", "low")
    }

    function networkIcon(key) {
        return barIcon("network", key)
    }

    function temperatureIcon(status) {
        return barIcon("temperature", status)
    }

    function weatherIcon(condition) {
        return barIcon("weather", condition)
    }

    function hasOverride(iconName) {
        return isBarIcon(source(iconName))
    }

    function source(iconName) {
        const mapped = legacyBarIcons[iconName]
        if (mapped)
            return barIcon(mapped.domain, mapped.name)
        return Quickshell.iconPath(iconName, "image-missing")
    }

    readonly property var legacyBarIcons: ({
        "bluetooth-active-symbolic": { domain: "bluetooth", name: "active" },
        "bluetooth-symbolic": { domain: "bluetooth", name: "idle" },
        "camera-video-symbolic": { domain: "privacy", name: "camera" },
        "emblem-favorite-symbolic": { domain: "shell", name: "info" },
        "media-optical-symbolic": { domain: "media", name: "optical" },
        "media-playback-pause-symbolic": { domain: "media", name: "pause" },
        "media-playback-start-symbolic": { domain: "media", name: "play" },
        "media-playback-stop-symbolic": { domain: "media", name: "stop" },
        "media-record-symbolic": { domain: "media", name: "record" },
        "media-skip-backward-symbolic": { domain: "media", name: "skip-backward" },
        "media-skip-forward-symbolic": { domain: "media", name: "skip-forward" },
        "mic-on": { domain: "privacy", name: "mic" },
        "system-search-symbolic": { domain: "launcher", name: "search" },
        "system-shutdown-symbolic": { domain: "menu", name: "shutdown" },
        "utilities-terminal-symbolic": { domain: "shell", name: "terminal" },
        "video-display-symbolic": { domain: "privacy", name: "display" },
    })

    function className(toplevel) {
        if (!toplevel)
            return ""

        const wayland = toplevel.wayland
        if (wayland && wayland.appId)
            return wayland.appId

        const ipc = toplevel.lastIpcObject
        if (ipc && ipc.class)
            return ipc.class

        if (ipc && ipc.initialClass)
            return ipc.initialClass

        return ""
    }

    function desktopEntryForClass(className) {
        if (!className)
            return null

        const direct = DesktopEntries.heuristicLookup(className)
        if (direct && direct.icon)
            return direct

        const normalized = className.toLowerCase()
        return DesktopEntries.applications.values.find((entry) => {
            const startup = (entry.startupClass || "").toLowerCase()
            if (startup && (normalized === startup || normalized.includes(startup)))
                return true

            const exec = entry.execString || ""
            const match = exec.match(/--app=(\S+)/)
            if (!match)
                return false

            try {
                const url = new URL(match[1])
                const host = url.hostname.replace(/^www\./, "").toLowerCase()
                const pathKey = url.pathname.replace(/^\/+|\/+$/g, "").replace(/\//g, "_").toLowerCase()
                return (host && normalized.includes(host))
                    || (pathKey && normalized.includes(pathKey))
            } catch (_) {
                return false
            }
        }) || null
    }

    function iconNameForToplevel(toplevel) {
        const appClass = className(toplevel)
        const desktopEntry = desktopEntryForClass(appClass)
        if (desktopEntry && desktopEntry.icon)
            return desktopEntry.icon

        if (appClass)
            return appClass

        return "application-x-executable"
    }
}
