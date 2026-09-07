pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.config

Singleton {
    id: root

    // Chosen over ":" because several fastfetch values (kernel strings, IPs,
    // GPU names) contain colons of their own.
    readonly property string separator: "=|="

    // The bonsai's canvas, in terminal cells. Fixing both dimensions is what
    // lets the art be redrawn without the panel changing size.
    readonly property int gridWidth: 40
    readonly property int gridHeight: 16
    readonly property int artSeed: 12345

    property bool loaded: false
    property string hostname: ""
    property string art: ""
    property var hardware: []
    property var software: []
    property string uptime: ""
    property string error: ""

    Component.onCompleted: {
        refresh()
        artProcess.running = true
    }

    function refresh() {
        if (!fetchProcess.running)
            fetchProcess.running = true
    }

    function saveCache() {
        if (!loaded)
            return
        infoCache.setText(JSON.stringify({
            hostname: hostname, hardware: hardware, software: software,
            uptime: uptime, art: art,
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
                if (!root.art)
                    root.art = String(saved.art || "")
            } catch (error) {}
        }
    }

    Process {
        id: fetchProcess

        command: ["bash", "-lc", `
            fastfetch --logo none --pipe --separator '${root.separator}' \
                --structure Title:Host:CPU:GPU:Display:Memory:OS:Kernel:WM:Uptime || exit $?
            df -h / | awk 'NR==2 {printf "Storage=|=%s / %s (%s)\\n", $3, $2, $5}'
            printf 'Terminal=|=%s\\n' "$(kitty --version | cut -d ' ' -f 1,2)"
            awk '/^font_family[[:space:]]/ {$1=""; family=substr($0,2)} /^font_size[[:space:]]/ {size=$2} END {if (family) printf "Font=|=%s (%spt)\\n", family, size}' ~/.config/kitty/kitty.conf
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

    // The one place the shell does not map onto base16. matugen collapses this
    // theme's base0B ("green") onto the same blue as base0D, and a bonsai that
    // is not green stops reading as a tree. Terminal colours here also keep the
    // art identical to the fastfetch report it is lifted from.
    readonly property var ansiPalette: ({
        "30": "#6b7280", "31": "#e06c75", "32": "#6a9955",
        "33": "#b58863", "34": "#61afef", "35": "#c678dd",
        "36": "#56b6c2", "37": "#c8ccd4",
        "90": "#8b93a1", "91": "#ef8b93", "92": "#98c379",
        "93": "#d19a66", "94": "#8ec7ff", "95": "#dc9ff0",
        "96": "#7fd4de", "97": "#e6e9ef"
    })

    // Same seed as the fastfetch config, so the panel grows the tree the
    // terminal report already draws. -g fixes the canvas at gridWidth x
    // gridHeight cells and every line is padded back out to that grid, so the
    // art occupies the same box no matter what it draws inside it.
    Process {
        id: artProcess

        command: ["bash", "-lc",
            `~/.config/fastfetch/scripts/bonsai.sh -n -L 20 -g ${root.gridWidth},${root.gridHeight} -T -s ${root.artSeed} 2>/dev/null`]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text.trim())
                    return
                root.art = root.ansiToMarkup(this.text)
                root.saveCache()
            }
        }
    }

    // The bonsai script emits SGR colour runs around single characters, which
    // become <font> spans on a grid-locked canvas.
    function ansiToMarkup(text) {
        const lines = text.split("\n").slice(0, root.gridHeight)
        while (lines.length < root.gridHeight)
            lines.push("")
        const canvas = lines.map(line => {
            const visible = line.replace(/\u001b\[[0-9;]*m/g, "").length
            return line + " ".repeat(Math.max(0, root.gridWidth - visible))
        }).join("\n")

        const parts = canvas.split(/\u001b\[([0-9;]*)m/)
        let markup = ""
        let color = ""

        for (let index = 0; index < parts.length; index++) {
            if (index % 2 === 1) {
                const code = parts[index].split(";").pop()
                color = code === "0" || code === "" ? "" : (root.ansiPalette[code] || color)
                continue
            }
            const chunk = parts[index]
                .replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;")
                .replace(/ /g, "&nbsp;")
                .replace(/\n/g, "<br>")
            if (chunk)
                markup += color ? `<font color="${color}">${chunk}</font>` : chunk
        }
        return markup
    }

    Timer {
        interval: StyleTokens.pollIntervalSlow
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
