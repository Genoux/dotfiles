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

    // First-party controls use Lucide, whose whole set is drawn with one fixed
    // 2px stroke on a 24px grid. That uniformity is the point: measured across
    // the shell's icons, Lucide's stroke width varies by 2.6% where Material
    // Symbols varied by 82%, which is what made a row of them look unbalanced.
    // The font ligates, so the icon's own name is its glyph. The prefix lets the
    // shared renderer distinguish font glyphs from app/theme image sources.
    function lucideIcon(name) {
        return `lucide:${name}`
    }

    // Application and tray icons remain application-owned.
    function themeIcon(name) {
        return Quickshell.iconPath(name, "image-missing")
    }

    readonly property var barControlIcons: ({
        bluetooth: "bluetooth",
        components: "layout-grid",
        dotfiles: "square-terminal",
        info: "heart",
        launcher: "search",
        power: "power",
        camera: "video",
        microphone: "mic",
        display: "monitor",
        recording: "video",
    })

    function barControlIcon(name) {
        const icon = barControlIcons[name]
        return icon ? lucideIcon(icon) : ""
    }

    readonly property var captureIcons: ({
        "idle": "scan",
        "recording": "video",
        "shot-region": "crop",
        "shot-window": "app-window",
        "shot-screen": "maximize",
        "record-region": "monitor-dot",
        "record-screen": "video",
        "audio-on": "mic",
        "audio-off": "mic-off",
        "folder": "folder-open",
        "copy": "copy",
        "copied": "check",
        "view": "eye",
        "edit": "pencil",
        "play": "play",
        "discard": "trash-2",
    })

    function captureIcon(name) {
        const icon = captureIcons[name]
        return icon ? lucideIcon(icon) : ""
    }

    function mediaIcon(name) {
        const icons = {
            "skip-backward": "skip-back",
            "play": "play",
            "pause": "pause",
            "skip-forward": "skip-forward",
        }
        return lucideIcon(icons[name] ?? "circle-stop")
    }

    function shellIcon(name) {
        const icons = {
            "chevron-left": "chevron-left",
            "chevron-right": "chevron-right",
        }
        return lucideIcon(icons[name] ?? name)
    }

    function isBarIcon(url) {
        const path = url?.toString?.() ?? String(url ?? "")
        return path.includes("assets/icons/")
    }

    // Lucide glyphs ink to 89% of their em where Material Symbols inked to 73%,
    // so drawing them at the icon box's full size renders 28% larger for the
    // same `iconSize`. This inset puts the ink back on the size the bar was
    // tuned around. Do not replace it with a per-glyph table: icon sets are
    // drawn to keylines, where a circle is intentionally larger than a square so
    // the two read as equal, and equalising measured boxes fights that.
    readonly property real glyphInset: 0.78

    function opticalScale(url) {
        const path = String(url ?? "")
        return path.startsWith("lucide:") ? glyphInset : 1
    }

    function batteryIcon(percent, charging) {
        if (charging)
            return lucideIcon("battery-charging")
        const levels = ["battery", "battery-low", "battery-low", "battery-medium",
                        "battery-medium", "battery-full", "battery-full", "battery-full"]
        const level = Math.max(0, Math.min(7, Math.round(percent / 100 * 7)))
        return lucideIcon(levels[level])
    }

    function volumeIcon(level, isMuted, hasSink) {
        if (!hasSink || isMuted)
            return lucideIcon("volume-off")
        if (level > 0.66)
            return lucideIcon("volume-2")
        if (level > 0.33)
            return lucideIcon("volume-1")
        return lucideIcon("volume")
    }

    function temperatureIcon(status) {
        return lucideIcon("thermometer")
    }

    // Weather used to render colour emoji, which put a filled, multicolour
    // cartoon in a row of monochrome hairline glyphs. These are the Material
    // Symbols equivalents so the strip reads as one set.
    function weatherIcon(condition) {
        const icons = {
            "clear": "sun",
            "clear-night": "moon",
            "few-clouds": "cloud-sun",
            "few-clouds-night": "cloud-moon",
            "fog": "cloud-fog",
            "overcast": "cloud",
            "showers-scattered": "cloud-drizzle",
            "showers": "cloud-rain",
            "snow": "cloud-snow",
            "storm": "cloud-lightning",
            "windy": "wind",
        }
        return lucideIcon(icons[condition] ?? "circle-help")
    }

    function bluetoothIcon(enabled) {
        return lucideIcon("bluetooth")
    }

    function networkIcon(name) {
        const icons = {
            "wireless": "wifi",
            "wireless-offline": "wifi-off",
            "wired": "network",
            "wired-offline": "unplug",
            "offline": "wifi-off",
        }
        return lucideIcon(icons[name] ?? "wifi-off")
    }

    function hasOverride(iconName) {
        return isBarIcon(source(iconName))
    }

    function source(iconName) {
        const glyph = symbolicAliases[iconName]
        return glyph ? lucideIcon(glyph) : themeIcon(iconName)
    }

    readonly property var symbolicAliases: ({
        "mic-on": "mic",
        "monitor-video": "monitor",
        "camera-video": "video",
        "bluetooth-active-symbolic": "bluetooth",
        "media-playback-stop-symbolic": "circle-stop",
        "media-record-symbolic": "circle-dot",
        "system-search-symbolic": "search",
        "utilities-terminal-symbolic": "square-terminal",
        "window-close-symbolic": "x",
        "system-lock-screen-symbolic": "lock",
        "system-suspend-symbolic": "moon",
        "system-reboot-symbolic": "rotate-cw",
        "system-shutdown-symbolic": "power",
        "system-log-out-symbolic": "log-out",
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
