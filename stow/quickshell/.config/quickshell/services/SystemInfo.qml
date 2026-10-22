pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    // Chosen over ":" because several fastfetch values (kernel strings, IPs,
    // GPU names) contain colons of their own.
    readonly property string separator: "=|="

    property bool loaded: false
    property string hostname: ""
    property var hardware: []
    property var software: []
    property string uptime: ""
    property string error: ""

    Component.onCompleted: refresh()

    function refresh() {
        if (!fetchProcess.running)
            fetchProcess.running = true
    }

    function saveCache() {
        if (!loaded)
            return
        infoCache.setText(JSON.stringify({
            hostname: hostname, hardware: hardware, software: software,
            uptime: uptime,
        }))
    }

    FileView {
        id: infoCache

        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache")
            + "/quickshell-system-info.json"
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text())
                if (!Array.isArray(saved.hardware) || !saved.hardware.length || !Array.isArray(saved.software))
                    return
                if (!root.loaded) {
                    root.hostname = String(saved.hostname || "")
                    root.hardware = saved.hardware
                    root.software = saved.software
                    root.uptime = String(saved.uptime || "")
                    root.loaded = true
                }
            } catch (error) {}
        }
    }

    Process {
        id: fetchProcess

        command: ["bash", "-c", `
            fastfetch --logo none --pipe --separator '${root.separator}' \
                --structure Title:Host:CPU:GPU:Display:Memory:OS:Kernel:WM:Uptime || exit $?
            df -h / | awk 'NR==2 {printf "Storage=|=%s / %s (%s)\\n", $3, $2, $5}'
            printf 'Terminal=|=%s\\n' "$(ghostty --version | head -n 1)"
            awk -F' *= *' '$1 == "font-family" {family=$2} $1 == "font-size" {size=$2} END {if (family) printf "Font=|=%s (%spt)\\n", family, size}' ~/.config/ghostty/config
            if test -f ~/.config/matugen/dotfiles-gum.env; then
                printf 'Theme=|=matugen\\n'
            fi
        `]

        onExited: exitCode => {
            if (exitCode !== 0 && !root.loaded)
                root.error = "System information is unavailable. Retrying in the background."
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const report = this.text
                const hardware = []
                const software = []

                for (const line of (report || "").trim().split("\n")) {
                    const parts = line.split(root.separator)
                    // The Title module prints bare "user@host" with no key.
                    if (parts.length < 2) {
                        if (line.trim())
                            root.hostname = line.trim().split("@").pop()
                        continue
                    }
                    const key = parts[0].trim()
                    const value = parts.slice(1).join(root.separator).trim()

                    if (key === "Uptime") {
                        root.uptime = value
                        continue
                    }
                    const label = key === "Host" ? "PC"
                        : key.startsWith("GPU") ? "Graphics"
                        : key.startsWith("Display") ? "Display"
                        : key === "WM" ? "Desktop" : key
                    const target = ["OS", "Kernel", "WM", "Terminal", "Font", "Theme"].includes(key)
                        ? software : hardware
                    const row = { label: label, value: value }
                    const memoryIndex = hardware.findIndex(item => item.label === "Memory")
                    if (key === "Storage" && memoryIndex >= 0)
                        hardware.splice(memoryIndex, 0, row)
                    else
                        target.push(row)
                }

                if (!hardware.length)
                    return

                root.hardware = hardware
                root.software = software
                root.error = ""

                root.loaded = true
                root.saveCache()
            }
        }
    }

    Timer {
        interval: StyleTokens.pollIntervalSlow
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
