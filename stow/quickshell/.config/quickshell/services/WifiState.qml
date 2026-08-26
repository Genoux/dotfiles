pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// Wi-Fi station state and control, backed by iwd's D-Bus API.
//
// Quickshell has no generic D-Bus binding, so reads go through one `busctl`
// call per poll and jq projects the ObjectManager tree into the shape this
// singleton exposes. Writes are individual `busctl` calls, except joining an
// unknown network: iwd takes the passphrase through a D-Bus agent, and iwctl
// is the only agent already installed.
Singleton {
    id: root

    // iwd reports signal as dBm x 100. -50 dBm and better is as good as a link
    // gets; below -80 it is usable only in principle. Four rungs between them,
    // matching the meter that draws them.
    readonly property int signalExcellent: -5000
    readonly property int signalGood: -6000
    readonly property int signalOk: -7000
    readonly property int signalWeak: -8000

    // The list only needs to be live while someone is looking at it.
    property bool detailed: false

    // The iwd Device object path. It survives the radio being powered off;
    // the Station interface on it does not.
    property string devicePath: ""
    property string interfaceName: ""
    property bool powered: false
    property string state: ""
    property bool scanning: false
    property string connectedPath: ""
    property var diagnostics: ({})
    property var networks: []
    property var known: []
    property bool loaded: false

    // A poll that reassigns these arrays tears down and rebuilds every row that
    // renders them, which would drop hover, a half-typed passphrase, and a
    // forget confirmation once a second. So a poll only reassigns when
    // something a row can actually see has changed, and RSSI noise inside one
    // strength rung is not that.
    property string networksSignature: ""
    property string knownSignature: ""

    // Which unconnected secured network has its passphrase field open. One at a
    // time: two open fields would leave the reader unsure which one Enter joins.
    property string passphrasePath: ""
    property string busyPath: ""
    property string errorPath: ""
    property string errorText: ""

    readonly property bool available: devicePath.length > 0
    readonly property bool connected: state === "connected"
    readonly property bool transitioning: state === "connecting" || state === "disconnecting" || state === "roaming"

    // Every list in this service hands out the same network shape, so a row can
    // render any of them without knowing which section it came from.
    readonly property var connectedNetwork: {
        for (const network of root.networks) {
            if (network.path !== root.connectedPath)
                continue

            return {
                path: network.path,
                knownPath: network.knownPath,
                name: network.name,
                type: network.type,
                strength: network.strength,
                inRange: true,
                saved: network.knownPath.length > 0,
            }
        }
        return null
    }

    // Known networks carry no signal of their own — that lives on the scan
    // result. Merge the two so a saved network in range shows its strength and
    // one out of range can say so.
    readonly property var savedNetworks: {
        const result = []
        for (const entry of root.known) {
            if (root.connectedNetwork && entry.path === root.connectedNetwork.knownPath)
                continue

            const scanned = root.scanResultFor(entry.path)
            result.push({
                path: scanned ? scanned.path : "",
                knownPath: entry.path,
                name: entry.name,
                type: entry.type,
                strength: scanned ? scanned.strength : 0,
                inRange: !!scanned,
                saved: true,
            })
        }
        result.sort(root.byStrengthThenName)
        return result
    }

    readonly property var openNetworks: {
        const result = []
        for (const network of root.networks) {
            if (network.connected || network.knownPath.length > 0)
                continue

            result.push({
                path: network.path,
                knownPath: "",
                name: network.name,
                type: network.type,
                strength: network.strength,
                inRange: true,
                saved: false,
            })
        }
        result.sort(root.byStrengthThenName)
        return result
    }

    readonly property int savedCount: savedNetworks.length
    readonly property int openCount: openNetworks.length

    // Strongest first, then alphabetical. Ordering by raw RSSI would reshuffle
    // neighbours on noise the reader cannot see in the meter.
    function byStrengthThenName(a, b) {
        if (a.strength !== b.strength)
            return b.strength - a.strength
        return a.name.localeCompare(b.name)
    }

    function applyNetworks(incoming) {
        const mapped = incoming.map((network) => ({
            path: network.path,
            name: network.name,
            type: network.type,
            connected: network.connected,
            knownPath: network.knownPath,
            strength: root.signalStrength(network.signal),
        }))

        const signature = mapped
            .map((network) => `${network.path}:${network.strength}:${network.connected}:${network.knownPath}`)
            .sort()
            .join("|")
        if (signature === root.networksSignature)
            return

        root.networksSignature = signature
        root.networks = mapped
    }

    function applyKnown(incoming) {
        const signature = incoming
            .map((entry) => `${entry.path}:${entry.name}:${entry.type}`)
            .sort()
            .join("|")
        if (signature === root.knownSignature)
            return

        root.knownSignature = signature
        root.known = incoming
    }

    function scanResultFor(knownPath) {
        for (const network of root.networks) {
            if (network.knownPath === knownPath)
                return network
        }
        return null
    }

    function signalStrength(signal) {
        if (signal >= signalExcellent)
            return 4
        if (signal >= signalGood)
            return 3
        if (signal >= signalOk)
            return 2
        if (signal >= signalWeak)
            return 1
        return 0
    }

    function requiresPassphrase(network) {
        return network.type === "psk" || network.type === "8021x"
    }

    // What the link *is*, not what it is doing this second. Bitrate and RSSI are
    // also in the diagnostics, and both jitter every poll — a status line that
    // reprints itself while being read is worse than one figure short.
    readonly property string connectionDetail: {
        const diagnostic = root.diagnostics
        if (!root.connected || !diagnostic)
            return ""

        const parts = []
        if (diagnostic.Security)
            parts.push(String(diagnostic.Security))
        if (diagnostic.Frequency)
            parts.push(diagnostic.Frequency > 3000 ? "5 GHz" : "2.4 GHz")
        if (diagnostic.Channel)
            parts.push("Ch " + diagnostic.Channel)
        return parts.join(" · ")
    }

    function clearError() {
        errorPath = ""
        errorText = ""
    }

    function refresh() {
        if (!readProcess.running)
            readProcess.running = true
    }

    function setPowered(on) {
        if (!devicePath.length)
            return

        clearError()
        // Powering the radio down cannot report through connectedPath, so drop
        // the passphrase field with it rather than leaving it orphaned.
        passphrasePath = ""
        writeProcess.exec([
            "busctl",
            "set-property",
            "net.connman.iwd",
            devicePath,
            "net.connman.iwd.Device",
            "Powered",
            "b",
            on ? "true" : "false",
        ])
    }

    function togglePowered() {
        setPowered(!powered)
    }

    function scan() {
        if (!devicePath.length || !powered || scanning)
            return

        clearError()
        // iwd returns InProgress if a scan is already running; ignore it rather
        // than surfacing a failure the user cannot act on.
        scanProcess.exec(["busctl", "call", "net.connman.iwd", devicePath, "net.connman.iwd.Station", "Scan"])
        refresh()
    }

    function disconnect() {
        if (!devicePath.length || !powered)
            return

        clearError()
        busyPath = connectedPath
        writeProcess.exec(["busctl", "call", "net.connman.iwd", devicePath, "net.connman.iwd.Station", "Disconnect"])
    }

    // Joining without supplying anything: iwd either already holds the
    // credentials or the network needs none, so no agent is involved.
    function connectDirect(network) {
        if (!network.inRange || !network.path.length)
            return

        clearError()
        busyPath = network.path
        connectProcess.exec(["busctl", "call", "net.connman.iwd", network.path, "net.connman.iwd.Network", "Connect"])
    }

    // ponytail: the passphrase reaches iwctl through argv, so it is briefly
    // readable in /proc for the length of the join. Registering our own
    // net.connman.iwd.Agent over D-Bus is the fix if that ever matters.
    function connectWithPassphrase(network, passphrase) {
        if (!interfaceName.length || !passphrase.length)
            return

        clearError()
        busyPath = network.path
        passphrasePath = ""
        connectProcess.exec([
            "iwctl",
            "--passphrase",
            passphrase,
            "--dont-ask",
            "station",
            interfaceName,
            "connect",
            network.name,
        ])
    }

    function activate(network) {
        if (busyPath.length > 0 || transitioning)
            return

        // A saved network already has credentials and an open one needs none.
        // Only a secured stranger has to ask for anything.
        if (network.saved || !requiresPassphrase(network)) {
            connectDirect(network)
            return
        }

        passphrasePath = passphrasePath === network.path ? "" : network.path
    }

    function forget(network) {
        if (!network.knownPath.length)
            return

        clearError()
        writeProcess.exec(["busctl", "call", "net.connman.iwd", network.knownPath, "net.connman.iwd.KnownNetwork", "Forget"])
    }

    Process {
        id: readProcess

        command: ["bash", "-c", `
        objs=$(busctl --json=short call net.connman.iwd / org.freedesktop.DBus.ObjectManager GetManagedObjects 2>/dev/null) || exit 0
        # Key on Device, not Station: iwd drops the Station interface while the
        # radio is powered off, and a tree keyed on Station would report the
        # adapter as gone and leave nothing to power back on.
        device=$(printf '%s' "$objs" | jq -r 'first(.data[0] | to_entries[] | select(.value["net.connman.iwd.Device"]) | .key) // empty')
        station=$(printf '%s' "$objs" | jq -r --arg d "$device" 'if $d != "" and (.data[0][$d]["net.connman.iwd.Station"] != null) then $d else "" end')
        ordered='{"data":[[]]}'
        diag='{"data":[{}]}'
        if [ -n "$station" ]; then
            ordered=$(busctl --json=short call net.connman.iwd "$station" net.connman.iwd.Station GetOrderedNetworks 2>/dev/null) || ordered='{"data":[[]]}'
            diag=$(busctl --json=short call net.connman.iwd "$station" net.connman.iwd.StationDiagnostic GetDiagnostics 2>/dev/null) || diag='{"data":[{}]}'
        fi
        printf '%s' "$objs" | jq -c --argjson ordered "$ordered" --argjson diag "$diag" --arg device "$device" '
          .data[0] as $o
          | ($ordered.data[0] // []) | map({key: .[0], value: .[1]}) | from_entries as $signal
          | ($diag.data[0] // {}) | with_entries(.value |= .data) as $d
          | ($o[$device]["net.connman.iwd.Device"] // {}) as $dev
          | ($o[$device]["net.connman.iwd.Station"] // {}) as $st
          | {
              device: $device,
              interface: ($dev.Name.data // ""),
              powered: ($dev.Powered.data // false),
              state: ($st.State.data // ""),
              scanning: ($st.Scanning.data // false),
              connectedPath: ($st.ConnectedNetwork.data // ""),
              diagnostics: $d,
              networks: [ $o | to_entries[]
                | select(.value["net.connman.iwd.Network"])
                | .value["net.connman.iwd.Network"] as $n
                | { path: .key,
                    name: ($n.Name.data // ""),
                    type: ($n.Type.data // ""),
                    connected: ($n.Connected.data // false),
                    knownPath: ($n.KnownNetwork.data // ""),
                    signal: ($signal[.key] // -10000) } ],
              known: [ $o | to_entries[]
                | select(.value["net.connman.iwd.KnownNetwork"])
                | .value["net.connman.iwd.KnownNetwork"] as $k
                | { path: .key,
                    name: ($k.Name.data // ""),
                    type: ($k.Type.data // ""),
                    hidden: ($k.Hidden.data // false),
                    autoConnect: ($k.AutoConnect.data // false) } ]
            }'
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text.length === 0) {
                    root.devicePath = ""
                    root.loaded = true
                    return
                }

                let payload = null
                try {
                    payload = JSON.parse(text)
                } catch (error) {
                    return
                }

                root.devicePath = payload.device ?? ""
                root.interfaceName = payload.interface ?? ""
                root.powered = payload.powered ?? false
                root.state = payload.state ?? ""
                root.scanning = payload.scanning ?? false
                root.connectedPath = payload.connectedPath ?? ""
                root.diagnostics = payload.diagnostics ?? ({})
                root.applyNetworks(payload.networks ?? [])
                root.applyKnown(payload.known ?? [])
                root.loaded = true

                // The action that set busyPath has landed once iwd stops
                // reporting a transition, so the spinner text is not left
                // behind on a row that already finished.
                if (root.busyPath.length > 0 && !root.transitioning)
                    root.busyPath = ""
            }
        }
    }

    Process {
        id: scanProcess
    }

    Process {
        id: writeProcess

        onExited: root.refresh()
    }

    Process {
        id: connectProcess

        stderr: StdioCollector {}

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.errorPath = root.busyPath
                root.errorText = "Could not connect"
            }
            root.busyPath = ""
            root.refresh()
        }
    }

    Timer {
        interval: root.detailed ? StyleTokens.pollIntervalFast : StyleTokens.pollIntervalNormal
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
