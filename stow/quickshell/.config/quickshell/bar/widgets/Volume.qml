import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services as Services

Button {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    iconName: Services.VolumeOsd.resolveIcon(!!sink, volume, muted)
    interactive: true
    onClicked: ShellActions.launchOrFocus("wiremix", "wiremix", "multimedia-volume-control")

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
