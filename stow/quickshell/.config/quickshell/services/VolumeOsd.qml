pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import qs.config

Singleton {
    id: root

    property bool visible: false
    property bool initializing: true
    property string iconName: "audio-volume-medium-symbolic"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: Math.min(root.sink?.audio?.volume ?? 0, 1)
    readonly property bool muted: root.sink?.audio?.muted ?? false

    property real _lastVolume: -1
    property bool _lastMuted: false

    function publishState() {
        const nextVolume = root.volume
        const nextMuted = root.muted
        const changed = nextVolume !== root._lastVolume || nextMuted !== root._lastMuted

        root.iconName = root.resolveIcon(nextVolume, nextMuted)

        if (!root.initializing && changed)
            root.show()

        root._lastVolume = nextVolume
        root._lastMuted = nextMuted
    }

    function resolveIcon(level, isMuted) {
        if (!root.sink || isMuted)
            return "audio-volume-muted-symbolic"
        if (level > 0.66)
            return "audio-volume-high-symbolic"
        if (level > 0.33)
            return "audio-volume-medium-symbolic"
        return "audio-volume-low-symbolic"
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

        interval: Style.osdHideDelay
        repeat: false
        onTriggered: root.visible = false
    }

    Timer {
        interval: Style.osdInitDelay
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

    Component.onCompleted: root.publishState()
}
