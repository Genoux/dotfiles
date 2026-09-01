pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Audio devices, levels, and per-application streams.
//
// Everything here is native: Quickshell's PipeWire binding exposes writable
// volume, mute, and preferred-default properties, so unlike WifiState this
// service runs no processes at all.
//
// The node lists are handed out as PipeWire's own object model rather than as
// filtered arrays. Filtering into a new array each time would give Repeater a
// fresh identity per evaluation and rebuild every delegate — which for a panel
// of sliders means the handle you are dragging is destroyed under the pointer.
// Views iterate the model and gate each delegate on the predicates below, the
// same way BluetoothPopover does with its device list.
Singleton {
    id: root

    readonly property var nodes: Pipewire.nodes

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property bool hasSink: !!sink
    readonly property bool hasSource: !!source

    readonly property real sinkVolume: root.volumeOf(root.sink)
    readonly property bool sinkMuted: root.mutedOf(root.sink)
    readonly property real sourceVolume: root.volumeOf(root.source)
    readonly property bool sourceMuted: root.mutedOf(root.source)

    // Bumped when a node's own properties change without the list length moving,
    // so the counts below re-evaluate.
    property int nodeRevision: 0
    property int pendingVolumeNodeId: -1
    property real pendingVolume: 0

    readonly property int outputCount: root.countMatching(root.isOutput)
    readonly property int inputCount: root.countMatching(root.isInput)
    readonly property int streamCount: root.countMatching(root.isPlaybackStream)

    // PwObjectTracker is what keeps volume and mute live; an untracked node
    // reports whatever it held when it was first seen.
    readonly property var trackedNodes: {
        const _ = root.nodeRevision
        const tracked = []
        for (const node of root.allNodes()) {
            if (node.audio)
                tracked.push(node)
        }
        return tracked
    }

    function allNodes() {
        return Pipewire.nodes.values ?? []
    }

    function countMatching(predicate) {
        const _ = root.nodeRevision
        let count = 0
        for (const node of root.allNodes()) {
            if (predicate(node))
                count++
        }
        return count
    }

    // A device is a node that is not a stream; direction comes from isSink. The
    // audio check drops PipeWire's bare Audio/Device entries, which carry no
    // level of their own.
    function isOutput(node) {
        return !!node?.audio && node.isSink && !node.isStream
    }

    function isInput(node) {
        return !!node?.audio && !node.isSink && !node.isStream
    }

    function isPlaybackStream(node) {
        return !!node?.audio && node.isStream && node.isSink
    }

    function volumeOf(node) {
        return Math.max(0, Math.min(1, node?.audio?.volume ?? 0))
    }

    function mutedOf(node) {
        return node?.audio?.muted ?? false
    }

    // PipeWire's description is what every desktop sound panel shows. Some nodes
    // ship none — Sunshine's virtual sinks report their bare name — so fall
    // through rather than rendering an empty row. No cleanup of the string: the
    // long ones elide, and pattern-matching vendor text would rot per device.
    function label(node) {
        if (!node)
            return ""

        const description = String(node.description ?? "").trim()
        if (description.length > 0)
            return description

        const nickname = String(node.nickname ?? "").trim()
        if (nickname.length > 0)
            return nickname

        return String(node.name ?? "")
    }

    // An application stream names itself in its node properties; the node's own
    // description is the track or pipeline, which changes as it plays.
    function streamLabel(node) {
        if (!node)
            return ""

        const properties = node.properties ?? ({})
        const application = String(properties["application.name"] ?? "").trim()
        if (application.length > 0)
            return application

        return root.label(node)
    }

    function isDefaultOutput(node) {
        return !!node && !!root.sink && node.id === root.sink.id
    }

    function isDefaultInput(node) {
        return !!node && !!root.source && node.id === root.source.id
    }

    function setVolume(node, volume) {
        if (!node?.audio)
            return

        const next = Math.max(0, Math.min(1, volume))
        pendingVolumeNodeId = node.id
        pendingVolume = next

        // Quickshell 0.3 echoes writes to some device nodes (notably BlueZ)
        // without committing them to PipeWire. Send the real write through
        // wpctl, coalesced so dragging does not spawn a process per pixel.
        if (!volumeFlush.running)
            volumeFlush.start()

        // Nudging the level of something muted is a request to hear it.
        if (node.audio.muted && next > 0)
            Quickshell.execDetached(["wpctl", "set-mute", String(node.id), "0"])
    }

    function toggleMute(node) {
        if (!node?.audio)
            return

        Quickshell.execDetached(["wpctl", "set-mute", String(node.id), "toggle"])
    }

    function selectOutput(node) {
        if (root.isOutput(node))
            Pipewire.preferredDefaultAudioSink = node
    }

    function selectInput(node) {
        if (root.isInput(node))
            Pipewire.preferredDefaultAudioSource = node
    }

    PwObjectTracker {
        objects: root.trackedNodes
    }

    Timer {
        id: volumeFlush

        interval: 25
        repeat: false
        onTriggered: {
            if (root.pendingVolumeNodeId < 0)
                return

            Quickshell.execDetached([
                "wpctl",
                "set-volume",
                String(root.pendingVolumeNodeId),
                String(root.pendingVolume),
            ])
        }
    }

    Instantiator {
        model: Pipewire.nodes

        delegate: Connections {
            required property var modelData

            target: modelData

            function onReadyChanged() {
                root.nodeRevision++
            }
        }

        onObjectAdded: root.nodeRevision++
        onObjectRemoved: root.nodeRevision++
    }
}
