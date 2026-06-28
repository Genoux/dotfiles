pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root

    property bool isOnline: false
    property string linkType: "unknown"

    function iconForInterface(interfaceName) {
        if (!interfaceName)
            return "unknown"

        if (interfaceName.startsWith("wl") || interfaceName.startsWith("wlan") || interfaceName.includes("wifi"))
            return "wireless"

        if (interfaceName.startsWith("eth") || interfaceName.startsWith("en"))
            return "wired"

        return "unknown"
    }

    function isIgnoredInterface(interfaceName) {
        return !interfaceName
            || interfaceName === "lo"
            || interfaceName.startsWith("docker")
            || interfaceName.startsWith("tailscale")
            || interfaceName.startsWith("tun")
            || interfaceName.startsWith("br-")
            || interfaceName.startsWith("veth")
    }

    function linkTypeFromRoute(output) {
        const match = output.match(/dev\s+(\w+)/)
        return match ? iconForInterface(match[1]) : "unknown"
    }

    function linkTypeFromAddresses(output) {
        let hasWireless = false
        let hasWired = false

        for (const line of output.split("\n")) {
            const match = line.match(/^\d+:\s+(\w+)\s+inet\s/)
            if (!match || isIgnoredInterface(match[1]))
                continue

            const type = iconForInterface(match[1])
            if (type === "wireless")
                hasWireless = true
            else if (type === "wired")
                hasWired = true
        }

        if (hasWired)
            return "wired"
        if (hasWireless)
            return "wireless"
        return "unknown"
    }

    function linkTypeFromInterfaces(output) {
        let hasWireless = false
        let hasWired = false

        for (const line of output.split("\n")) {
            const match = line.match(/^\d+:\s+(\w+):.*state UP/)
            if (!match || isIgnoredInterface(match[1]))
                continue

            const type = iconForInterface(match[1])
            if (type === "wireless")
                hasWireless = true
            else if (type === "wired")
                hasWired = true
        }

        if (hasWireless)
            return "wireless"
        if (hasWired)
            return "wired"
        return "unknown"
    }

    function refresh() {
        routeProcess.running = true
    }

    Process {
        id: routeProcess

        command: ["bash", "-c", "ip route get 8.8.8.8 2>/dev/null || true; echo ---ADDR---; ip -4 -o addr show scope global 2>/dev/null || true; echo ---LINK---; ip link show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text
                const routeOutput = text.split("---ADDR---")[0]?.trim() ?? ""
                const addrPart = text.split("---ADDR---")[1] ?? ""
                const addrOutput = addrPart.split("---LINK---")[0]?.trim() ?? ""
                const linkOutput = addrPart.split("---LINK---")[1]?.trim() ?? ""

                root.isOnline = routeOutput.length > 0 && /dev\s+\w+/.test(routeOutput)
                root.linkType = root.isOnline
                    ? root.linkTypeFromRoute(routeOutput)
                    : root.linkTypeFromAddresses(addrOutput) !== "unknown"
                        ? root.linkTypeFromAddresses(addrOutput)
                        : root.linkTypeFromInterfaces(linkOutput)
            }
        }
    }

    Timer {
        interval: StyleTokens.pollIntervalNormal
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
