pragma Singleton

import Quickshell
import QtQml
import QtQuick

Singleton {
    // DesktopEntries.applications only populates once something binds it as a
    // model; without this every lookup below sees an empty list
    readonly property Instantiator desktopEntries: Instantiator {
        model: DesktopEntries.applications
        delegate: QtObject {}
    }

    // First-party shell symbols come from the active MacTahoe icon theme.
    // Application and tray icons remain application-owned.
    function themeIcon(name) {
        return Quickshell.iconPath(name, "image-missing")
    }

    readonly property var barControlIcons: ({
        bluetooth: "bluetooth-active-symbolic",
        components: "view-grid-symbolic",
        dotfiles: "utilities-terminal-symbolic",
        info: "emblem-favorite-symbolic",
        launcher: "system-search-symbolic",
        power: "system-shutdown-symbolic",
        camera: "camera-video-symbolic",
        microphone: "audio-input-microphone-symbolic",
        display: "video-display-symbolic",
        recording: "media-record-symbolic",
    })

    function barControlIcon(name) {
        const icon = barControlIcons[name]
        return icon ? themeIcon(icon) : ""
    }

    readonly property var captureIcons: ({
        "idle": "gnome-photos-symbolic",
        "recording": "media-record-symbolic",
        "shot-region": "crop-symbolic",
        "shot-window": "window-symbolic",
        "shot-screen": "video-display-symbolic",
        "record-region": "media-record-symbolic",
        "record-screen": "camera-video-symbolic",
        "audio-on": "audio-input-microphone-symbolic",
        "audio-off": "audio-input-microphone-muted-symbolic",
        "delay": "tools-timer-symbolic",
        "folder": "folder-symbolic",
        "copy": "edit-copy-symbolic",
        "copied": "emblem-ok-symbolic",
        "view": "view-reveal-symbolic",
        "edit": "edit-select-invert-symbolic",
        "play": "media-playback-start-symbolic",
        "discard": "user-trash-symbolic",
    })

    function captureIcon(name) {
        const icon = captureIcons[name]
        return icon ? themeIcon(icon) : ""
    }

    function mediaIcon(name) {
        const icons = {
            "skip-backward": "media-skip-backward-symbolic",
            "play": "media-playback-start-symbolic",
            "pause": "media-playback-pause-symbolic",
            "skip-forward": "media-skip-forward-symbolic",
        }
        return themeIcon(icons[name] ?? "media-playback-stop-symbolic")
    }

    function shellIcon(name) {
        const icons = {
            "chevron-left": "go-previous-symbolic",
            "chevron-right": "go-next-symbolic",
            "navigation": "find-location-symbolic",
        }
        return themeIcon(icons[name] ?? name)
    }

    function batteryIcon(percent, charging) {
        if (charging)
            return themeIcon("battery-level-100-charged-symbolic")
        const levels = ["battery-level-10-symbolic", "battery-level-20-symbolic",
                        "battery-level-20-symbolic", "battery-level-40-symbolic",
                        "battery-level-60-symbolic", "battery-level-80-symbolic",
                        "battery-level-100-symbolic", "battery-level-100-symbolic"]
        const level = Math.max(0, Math.min(7, Math.round(percent / 100 * 7)))
        return themeIcon(levels[level])
    }

    function volumeIcon(level, isMuted, hasSink) {
        if (!hasSink || isMuted)
            return themeIcon("audio-volume-muted-symbolic")
        if (level > 0.66)
            return themeIcon("audio-volume-high-symbolic")
        if (level > 0.33)
            return themeIcon("audio-volume-medium-symbolic")
        return themeIcon("audio-volume-low-symbolic")
    }

    function temperatureIcon(status) {
        return themeIcon("temperature-symbolic")
    }

    // Use the theme's dedicated weather family so the bar, header, and forecast
    // rows share the same small-size optical treatment.
    function weatherIcon(condition) {
        const icons = {
            "clear": "weather-clear-symbolic",
            "clear-night": "weather-clear-night-symbolic",
            "few-clouds": "weather-few-clouds-symbolic",
            "few-clouds-night": "weather-few-clouds-night-symbolic",
            "fog": "weather-fog-symbolic",
            "overcast": "weather-overcast-symbolic",
            "showers-scattered": "weather-showers-scattered-symbolic",
            "showers": "weather-showers-symbolic",
            "snow": "weather-snow-symbolic",
            "storm": "weather-storm-symbolic",
            "windy": "weather-windy-symbolic",
        }
        return themeIcon(icons[condition] ?? "weather-overcast-symbolic")
    }

    function bluetoothIcon(enabled) {
        return themeIcon("bluetooth-active-symbolic")
    }

    function networkIcon(name) {
        const icons = {
            "wireless": "network-wireless-signal-excellent-symbolic",
            "wireless-offline": "network-wireless-offline-symbolic",
            // A Wi-Fi fan is now the universal shorthand for internet access;
            // using it for Ethernet keeps the bar cleaner than a topology icon.
            "wired": "network-wireless-signal-excellent-symbolic",
            "wired-offline": "network-wireless-offline-symbolic",
            "offline": "network-wireless-offline-symbolic",
        }
        return themeIcon(icons[name] ?? "network-wireless-offline-symbolic")
    }

    function source(iconName) {
        return themeIcon(symbolicAliases[iconName] ?? iconName)
    }

    readonly property var symbolicAliases: ({
        "mic-on": "audio-input-microphone-symbolic",
        "monitor-video": "video-display-symbolic",
        "camera-video": "camera-video-symbolic",
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

    // A playback stream names the application that owns it but carries no icon,
    // so resolve it through the same desktop-entry lookup a window class uses.
    // Candidates run binary first: it is the stable identifier ("spotify"), while
    // application.name is display text that can be translated or decorated.
    function streamIcon(properties) {
        const props = properties ?? ({})

        const declared = String(props["application.icon_name"] ?? "").trim()
        if (declared.length > 0) {
            const themed = Quickshell.iconPath(declared, true)
            if (String(themed).length > 0)
                return themed
        }

        const candidates = [
            props["application.process.binary"],
            props["application.name"],
            props["node.name"],
        ]

        for (const candidate of candidates) {
            const entry = desktopEntryForClass(String(candidate ?? "").trim())
            if (entry?.icon) {
                const resolved = Quickshell.iconPath(entry.icon, true)
                if (String(resolved).length > 0)
                    return resolved
            }
        }

        // Nothing identified it, but it is still audibly playing — say that much.
        return volumeIcon(1, false, true)
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
