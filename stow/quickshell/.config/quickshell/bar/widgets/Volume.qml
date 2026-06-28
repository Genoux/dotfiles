import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services as Services

Button {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property bool hasSink: !!sink

    readonly property string volumeIconName: {
        if (!hasSink || muted)
            return "audio-volume-muted-symbolic"
        if (volume <= 0.25)
            return "audio-volume-low-symbolic"
        if (volume <= 0.75)
            return "audio-volume-medium-symbolic"
        if (volume <= 1.0)
            return "audio-volume-high-symbolic"
        return "audio-volume-overamplified-symbolic"
    }

    iconName: volumeIconName
    interactive: true
    onClicked: ShellActions.launchOrFocus("wiremix", "wiremix", "multimedia-volume-control")

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
