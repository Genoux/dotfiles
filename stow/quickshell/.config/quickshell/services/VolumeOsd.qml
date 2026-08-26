pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import qs.config

Singleton {
    id: root

    property bool visible: false
    property bool initializing: true

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: Math.min(root.sink?.audio?.volume ?? 0, 1)
    readonly property bool muted: root.sink?.audio?.muted ?? false
    readonly property bool sinkReady: root.sink?.ready ?? false

    property real _lastVolume: -1
    property bool _lastMuted: false
    property int _baselineSinkId: -1
    property bool _publishing: false

    // Reading a tracked property here is enough to emit another change, so every
    // handler below can re-enter this mid-run. A nested call finishing first
    // would rewrite the baseline the outer call is still comparing against —
    // seen as one call holding `swapped` true while the same identity check read
    // false three lines later. Dropping the nested call is safe: the churn it
    // reports is exactly what the settle window ignores anyway.
    function publishState() {
        if (root._publishing)
            return

        root._publishing = true

        const nextVolume = root.volume
        const nextMuted = root.muted
        const nextSinkId = root.sink?.id ?? -1
        const swapped = nextSinkId !== root._baselineSinkId

        if (swapped)
            settleTimer.restart()

        // Levels are per-device, so a swap reports numbers differing from the
        // previous sink's no matter what the user did. Identity gates the
        // announcement; the levels only mean anything once they belong to the
        // sink we are actually on now.
        // Two windows produce level changes nobody asked for, and each gate below
        // catches only one of them. A sink being torn down reports its volume
        // dropping to zero while it is still the default and still has a live
        // audio object — only its `ready` flag goes false, so that is the one
        // signal separating it from a real change. A sink just promoted reports
        // its own levels arriving late, with `ready` flickering true/false/true,
        // so readiness cannot gate that one and the settle window has to.
        const worthShowing = swapped
            ? root.sinkTookOver()
            : !settleTimer.running && root.sinkReady
                && (nextVolume !== root._lastVolume || nextMuted !== root._lastMuted)

        if (!root.initializing && worthShowing)
            root.show()

        root._lastVolume = nextVolume
        root._lastMuted = nextMuted
        root._baselineSinkId = nextSinkId
        root._publishing = false
    }

    // Worth announcing when something new took the default while the sink we were
    // on is still present: a headset connected, or an output picked by hand. If
    // that sink is gone we were only pushed onto a fallback, which is a
    // consequence of the disconnect rather than a choice. Removal often routes
    // through a null default first, which arrives here as a -1 baseline and is
    // equally not worth announcing.
    function sinkTookOver() {
        if (root._baselineSinkId === -1 || !root.sink)
            return false

        return Pipewire.nodes.values.some(node => node.id === root._baselineSinkId)
    }

    function show() {
        root.visible = true
        hideTimer.restart()
    }

    function hide() {
        hideTimer.stop()
        root.visible = false
    }

    Timer {
        id: hideTimer

        interval: StyleOsd.hideDelay
        repeat: false
        onTriggered: root.visible = false
    }

    // A promoted sink's volume lands only after PwObjectTracker rebinds, and the
    // node's own `ready` flag goes true/false/true while that happens — so it
    // cannot tell arriving data from a change the user made. Ignore levels until
    // the churn stops instead.
    Timer {
        id: settleTimer

        interval: StyleOsd.settleDelay
        repeat: false
    }

    Timer {
        interval: StyleOsd.initDelay
        running: true
        repeat: false
        onTriggered: root.initializing = false
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    onVolumeChanged: root.publishState()
    onMutedChanged: root.publishState()
    onSinkChanged: root.publishState()
    onSinkReadyChanged: root.publishState()

    Component.onCompleted: root.publishState()
}
