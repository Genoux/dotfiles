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

    function barIcon(domain, name) {
        // shellPath returns a bare filesystem path on some quickshell versions;
        // without a scheme it resolves against qrc: inside IconImage and fails
        const path = String(Quickshell.shellPath(`assets/icons/${domain}/${name}.svg`))
        return path.startsWith("/") ? "file://" + path : path
    }

    // First-party controls use Material Symbols Rounded, which is installed by
    // this repo and uses one consistent 24px design grid. The prefix lets the
    // shared renderer distinguish font glyphs from app/theme image sources.
    function materialIcon(name) {
        return `material-symbols:${name}`
    }

    // Application and tray icons remain application-owned.
    function themeIcon(name) {
        return Quickshell.iconPath(name, "image-missing")
    }

    readonly property var barControlIcons: ({
        bluetooth: "bluetooth",
        components: "widgets",
        dotfiles: "terminal",
        info: "favorite",
        launcher: "search",
        power: "power_settings_new",
        camera: "videocam",
        microphone: "mic",
        display: "desktop_windows",
        recording: "videocam",
    })

    function barControlIcon(name) {
        const icon = barControlIcons[name]
        return icon ? materialIcon(icon) : ""
    }

    readonly property var captureIcons: ({
        "idle": "screenshot_frame",
        "recording": "videocam",
        "shot-region": "screenshot_region",
        "shot-window": "select_window",
        "shot-screen": "fullscreen",
        "record-region": "screen_record",
        "record-screen": "videocam",
        "audio-on": "mic",
        "audio-off": "mic_off",
        "folder": "folder_open",
        "copy": "content_copy",
        "edit": "edit",
        "play": "play_arrow",
        "discard": "delete",
    })

    function captureIcon(name) {
        const icon = captureIcons[name]
        return icon ? materialIcon(icon) : ""
    }

    function mediaIcon(name) {
        const icons = {
            "skip-backward": "skip_previous",
            "play": "play_arrow",
            "pause": "pause",
            "skip-forward": "skip_next",
        }
        return materialIcon(icons[name] ?? "stop_circle")
    }

    function shellIcon(name) {
        const icons = {
            "chevron-left": "chevron_left",
            "chevron-right": "chevron_right",
        }
        return materialIcon(icons[name] ?? name)
    }

    function isBarIcon(url) {
        const path = url?.toString?.() ?? String(url ?? "")
        return path.includes("assets/icons/")
    }

    // Material Symbols share a 24px design grid, so they get one mathematical
    // inset rather than subjective per-widget sizes. App/theme icons retain
    // their native canvas because their geometry is not under shell control.
    function opticalScale(url) {
        const path = String(url ?? "")
        if (path.startsWith("material-symbols:"))
            return 0.94
        return 1
    }

    function batteryIcon(percent, charging) {
        if (charging)
            return materialIcon("battery_charging_full")
        const level = Math.max(0, Math.min(7, Math.round(percent / 100 * 7)))
        return materialIcon(level === 7 ? "battery_full" : `battery_${level}_bar`)
    }

    function volumeIcon(level, isMuted, hasSink) {
        if (!hasSink || isMuted)
            return materialIcon("volume_off")
        if (level > 0.66)
            return materialIcon("volume_up")
        if (level > 0.33)
            return materialIcon("volume_down")
        return materialIcon("volume_mute")
    }

    function temperatureIcon(status) {
        return materialIcon("device_thermostat")
    }

    function weatherIcon(condition) {
        const icons = {
            "clear": "☀️",
            "clear-night": "🌙",
            "few-clouds": "🌤️",
            "few-clouds-night": "☁️",
            "fog": "🌫️",
            "overcast": "☁️",
            "showers-scattered": "🌦️",
            "showers": "🌧️",
            "snow": "🌨️",
            "storm": "⛈️",
            "windy": "💨",
        }
        return `emoji:${icons[condition] ?? "❔"}`
    }

    function bluetoothIcon(enabled) {
        return materialIcon("bluetooth")
    }

    function networkIcon(name) {
        const icons = {
            "wireless": "wifi",
            "wireless-offline": "wifi_off",
            "wired": "lan",
            "wired-offline": "signal_wifi_bad",
            "offline": "signal_wifi_bad",
        }
        return materialIcon(icons[name] ?? "signal_wifi_bad")
    }

    function hasOverride(iconName) {
        return isBarIcon(source(iconName))
    }

    function source(iconName) {
        const glyph = symbolicAliases[iconName]
        return glyph ? materialIcon(glyph) : themeIcon(iconName)
    }

    readonly property var symbolicAliases: ({
        "mic-on": "mic",
        "monitor-video": "desktop_windows",
        "camera-video": "videocam",
        "bluetooth-active-symbolic": "bluetooth",
        "media-playback-stop-symbolic": "stop_circle",
        "media-record-symbolic": "radio_button_checked",
        "system-search-symbolic": "search",
        "utilities-terminal-symbolic": "terminal",
        "window-close-symbolic": "close",
        "system-lock-screen-symbolic": "lock",
        "system-suspend-symbolic": "bedtime",
        "system-reboot-symbolic": "restart_alt",
        "system-shutdown-symbolic": "power_settings_new",
        "system-log-out-symbolic": "logout",
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
