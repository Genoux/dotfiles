pragma Singleton

import Quickshell
import Quickshell.Bluetooth as Bluez
import Quickshell.Io
import QtCore
import QtQuick

Singleton {
    id: root

    readonly property int scanTimeoutMs: 12000
    readonly property int reconnectDelayMs: 1500
    readonly property int maxReconnectAttempts: 6
    readonly property int powerVerifyDelayMs: 1000
    readonly property int maxPowerAttempts: 3
    readonly property string statePath: `${StandardPaths.writableLocation(StandardPaths.HomeLocation)}/.local/state/quickshell/bluetooth.json`

    readonly property var adapter: Bluez.Bluetooth.defaultAdapter
    readonly property bool available: !!adapter
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property bool blocked: adapter?.state === Bluez.BluetoothAdapterState.Blocked
    readonly property int knownCount: adapter ? adapter.devices.values.length : 0

    // Bumped when a device's connection/pair state changes without the list
    // length changing, so section filters re-evaluate.
    property int deviceRevision: 0

    readonly property int connectedCount: {
        const _ = root.deviceRevision
        const _len = root.knownCount
        let count = 0
        for (const device of root.knownDevices()) {
            if (device.connected)
                count++
        }
        return count
    }

    readonly property int pairedIdleCount: {
        const _ = root.deviceRevision
        const _len = root.knownCount
        let count = 0
        for (const device of root.knownDevices()) {
            if (device.paired && !device.connected && !device.blocked)
                count++
        }
        return count
    }

    readonly property int nearbyCount: {
        const _ = root.deviceRevision
        const _len = root.knownCount
        let count = 0
        for (const device of root.knownDevices()) {
            if (!device.paired && !device.connected && !device.blocked)
                count++
        }
        return count
    }

    property string pendingPairAddress: ""
    property string lastConnectedAddress: stateFile.adapter?.lastConnectedAddress ?? ""
    property bool reconnectOnEnable: false
    property bool requestedAdapterEnabled: false
    property int reconnectAttempts: 0
    property int powerAttempts: 0
    property string pendingAudioAddress: ""

    function knownDevices() {
        if (!adapter)
            return []
        return adapter.devices.values ?? []
    }

    function bumpDevices() {
        deviceRevision++
    }

    function isAudioDevice(device) {
        const icon = String(device?.icon || "")
        return icon.startsWith("audio-")
    }

    function cardIdFromAddress(address) {
        return String(address || "").replace(/:/g, "_")
    }

    function connectedAddresses() {
        const addresses = []
        for (const device of root.knownDevices()) {
            if (device.connected)
                addresses.push(device.address)
        }
        return addresses
    }

    function persistLastConnected(address) {
        const value = String(address || "")
        if (!stateFile.adapter)
            return

        lastConnectedAddress = value
        stateFile.adapter.lastConnectedAddress = value
        stateFile.writeAdapter()
    }

    function findDevice(address) {
        for (const device of root.knownDevices()) {
            if (device.address === address)
                return device
        }
        return null
    }

    function toggleAdapter() {
        if (!adapter || blocked)
            return
        if (adapter.enabled)
            disableAdapter()
        else
            enableAdapter()
    }

    function disableAdapter() {
        stopScan()
        reconnectOnEnable = false
        requestedAdapterEnabled = false
        powerAttempts = 0

        const connected = connectedAddresses()
        if (lastConnectedAddress.length === 0 && connected.length > 0)
            persistLastConnected(connected[0])

        // Quickshell 0.3.0 can retain a dangling PipeWire default pointer if
        // the default Bluetooth sink is destroyed. Move the default while the
        // node is still alive, then power BlueZ off from the same process.
        powerOffProcess.exec([
            "bash",
            "-c",
            root.releaseAudioScript() + `
            bluetoothctl power off
            `,
            "bluetooth-power-off",
            "",
        ])
    }

    function enableAdapter() {
        reconnectOnEnable = true
        requestedAdapterEnabled = true
        reconnectAttempts = 0
        powerAttempts = 0
        adapter.enabled = true
        if (adapter.enabled)
            reconnectTimer.restart()
        powerVerifyTimer.restart()
    }

    function reconnectLastDevice() {
        if (!adapter?.enabled)
            return

        if (lastConnectedAddress.length === 0) {
            reconnectOnEnable = false
            return
        }

        const device = findDevice(lastConnectedAddress)
        if (device?.connected) {
            reconnectOnEnable = false
            activateAudioSink(device)
            return
        }

        const transitioning = device?.state === Bluez.BluetoothDeviceState.Connecting
            || device?.state === Bluez.BluetoothDeviceState.Disconnecting
        if (transitioning) {
            reconnectAttempts++
            if (reconnectAttempts < maxReconnectAttempts)
                reconnectTimer.restart()
            else
                reconnectOnEnable = false
            return
        }

        if (device?.blocked) {
            reconnectOnEnable = false
            return
        }

        if (device)
            device.trusted = true

        if (!reconnectProcess.running)
            reconnectProcess.exec(["bluetoothctl", "connect", lastConnectedAddress])

        reconnectAttempts++
        if (reconnectAttempts < maxReconnectAttempts)
            reconnectTimer.restart()
        else
            reconnectOnEnable = false
    }

    function startScan() {
        if (!adapter || !adapter.enabled)
            return
        adapter.discovering = true
        scanStopTimer.restart()
    }

    function stopScan() {
        scanStopTimer.stop()
        if (adapter)
            adapter.discovering = false
    }

    function toggleScan() {
        if (discovering)
            stopScan()
        else
            startScan()
    }

    function activateDevice(device) {
        if (!device || device.blocked)
            return

        const busy = device.pairing
            || device.state === Bluez.BluetoothDeviceState.Connecting
            || device.state === Bluez.BluetoothDeviceState.Disconnecting
        if (busy)
            return

        if (!device.paired) {
            pendingPairAddress = device.address
            device.trusted = true
            device.pair()
            return
        }

        device.connect()
    }

    function forgetDevice(device) {
        if (!device)
            return
        if (pendingPairAddress === device.address)
            pendingPairAddress = ""
        if (lastConnectedAddress === device.address)
            persistLastConnected("")
        device.forget()
    }

    function releaseAudioScript() {
        return `
        current=$(pactl get-default-sink 2>/dev/null || true)
        release_default=false
        case "$current" in
            bluez_output.*)
                if [ -z "$1" ] || [[ "$current" == *"$1"* ]]; then
                    release_default=true
                fi
                ;;
        esac

        if $release_default; then
                fallback=$(pactl list short sinks 2>/dev/null \
                    | awk '$2 !~ /^bluez_output/ && $2 !~ /^sink-sunshine-/ && $2 !~ /snd_aloop/ { print $2; exit }')
                if [ -n "$fallback" ]; then
                    pactl set-default-sink "$fallback"
                else
                    wpctl clear-default >/dev/null 2>&1 || true
                    pw-metadata -n default -d 0 default.audio.sink >/dev/null 2>&1 || true
                fi
                sleep 0.2
        fi
        `
    }

    function disconnectDevice(device) {
        if (!device)
            return
        if (!isAudioDevice(device)) {
            device.disconnect()
            return
        }

        disconnectProcess.exec([
            "bash",
            "-c",
            root.releaseAudioScript() + `
            bluetoothctl disconnect "$2"
            `,
            "bluetooth-disconnect",
            root.cardIdFromAddress(device.address),
            device.address,
        ])
    }

    function activateAudioSink(device) {
        if (!device || !isAudioDevice(device) || !device.connected)
            return
        pendingAudioAddress = device.address

        const id = cardIdFromAddress(device.address)
        audioProfileProcess.exec([
            "bash",
            "-c",
            `
            card="bluez_card.$1"
            profile_set=false
            for _ in $(seq 1 20); do
                if pactl set-card-profile "$card" a2dp-sink 2>/dev/null; then
                    profile_set=true
                    break
                fi
                sleep 0.25
            done
            $profile_set || exit 1

            for _ in $(seq 1 20); do
                sink=$(pactl list short sinks 2>/dev/null | awk -v id="$1" '$2 ~ id { print $2; exit }')
                if [ -n "$sink" ]; then
                    pactl set-default-sink "$sink"
                    pactl set-sink-mute "$sink" 0
                    pactl list short sink-inputs 2>/dev/null | while read -r input _; do
                        pactl move-sink-input "$input" "$sink" 2>/dev/null || true
                    done
                    exit 0
                fi
                sleep 0.25
            done
            exit 1
            `,
            "bluetooth-audio",
            id,
        ])
    }

    Timer {
        id: scanStopTimer

        interval: root.scanTimeoutMs
        onTriggered: root.stopScan()
    }

    Timer {
        id: reconnectTimer

        interval: root.reconnectDelayMs
        onTriggered: root.reconnectLastDevice()
    }

    Timer {
        id: powerVerifyTimer

        interval: root.powerVerifyDelayMs
        onTriggered: {
            if (!root.adapter || root.adapter.enabled === root.requestedAdapterEnabled)
                return

            root.powerAttempts++
            powerProcess.exec(["bluetoothctl", "power", root.requestedAdapterEnabled ? "on" : "off"])
            if (root.powerAttempts < root.maxPowerAttempts)
                powerVerifyTimer.restart()
        }
    }

    Process {
        id: audioProfileProcess
    }

    Process {
        id: powerProcess
    }

    Process {
        id: powerOffProcess

        onExited: powerVerifyTimer.restart()
    }

    Process {
        id: disconnectProcess
    }

    Process {
        id: reconnectProcess
    }

    Process {
        command: ["mkdir", "-p", `${StandardPaths.writableLocation(StandardPaths.HomeLocation)}/.local/state/quickshell`]
        running: true
    }

    FileView {
        id: stateFile

        path: root.statePath
        watchChanges: true
        printErrors: false
        preload: true

        JsonAdapter {
            property string lastConnectedAddress: ""
        }
    }

    Connections {
        target: root.adapter

        function onEnabledChanged() {
            if (root.adapter?.enabled && root.reconnectOnEnable)
                reconnectTimer.restart()
        }
    }

    Instantiator {
        model: root.adapter ? root.adapter.devices : 0

        delegate: Connections {
            required property var modelData

            target: modelData

            Component.onCompleted: {
                if (modelData.connected) {
                    if (root.lastConnectedAddress.length === 0)
                        root.persistLastConnected(modelData.address)
                    root.activateAudioSink(modelData)
                }
            }

            function onConnectedChanged() {
                root.bumpDevices()
                if (modelData.connected) {
                    root.persistLastConnected(modelData.address)
                    if (modelData.address === root.lastConnectedAddress) {
                        root.reconnectOnEnable = false
                        reconnectTimer.stop()
                    }
                    root.activateAudioSink(modelData)
                }
            }

            function onPairedChanged() {
                root.bumpDevices()
                if (modelData.paired && modelData.address === root.pendingPairAddress) {
                    root.pendingPairAddress = ""
                    if (!modelData.connected)
                        modelData.connect()
                }
            }

            function onPairingChanged() {
                if (!modelData.pairing && root.pendingPairAddress === modelData.address && !modelData.paired)
                    root.pendingPairAddress = ""
            }

            function onBlockedChanged() {
                root.bumpDevices()
            }

            function onNameChanged() {
                root.bumpDevices()
            }

            function onStateChanged() {
                root.bumpDevices()
            }
        }

        onObjectAdded: root.bumpDevices()
        onObjectRemoved: root.bumpDevices()
    }

    Component.onCompleted: Qt.callLater(root.activateConnectedAudio)

    function activateConnectedAudio() {
        for (const device of root.knownDevices()) {
            if (device.connected)
                root.activateAudioSink(device)
        }
    }
}
