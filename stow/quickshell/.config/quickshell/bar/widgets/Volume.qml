import Quickshell.Services.Pipewire
import qs.config
import qs.components

IconButton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    iconName: !sink || muted
        ? "audio-volume-muted-symbolic"
        : volume > 0.66
            ? "audio-volume-high-symbolic"
            : volume > 0.33
                ? "audio-volume-medium-symbolic"
                : "audio-volume-low-symbolic"
    interactive: true
    onClicked: ShellActions.launchOrFocus("wiremix", "wiremix", "multimedia-volume-control")

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
