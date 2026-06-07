pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property var overrides: ({
        "emblem-favorite-symbolic": "emblem-favorite-symbolic.svg",
        "network-wireless-symbolic": "network-wireless-symbolic.svg",
        "network-idle": "network-idle-symbolic.svg",
        "network-offline-symbolic": "network-offline-symbolic.svg",
        "audio-volume-high-symbolic": "audio-volume-high-symbolic.svg",
        "audio-volume-medium-symbolic": "audio-volume-medium-symbolic.svg",
        "audio-volume-low-symbolic": "audio-volume-low-symbolic.svg",
        "audio-volume-muted-symbolic": "audio-volume-muted-symbolic.svg",
        "bluetooth-active-symbolic": "bluetooth-active-symbolic.svg",
        "media-optical-symbolic": "media-optical-symbolic.svg",
        "media-playback-stop-symbolic": "media-playback-stop-symbolic.svg",
        "media-skip-backward-symbolic": "media-skip-backward-symbolic.svg",
        "media-playback-start-symbolic": "media-playback-start-symbolic.svg",
        "media-playback-pause-symbolic": "media-playback-pause-symbolic.svg",
        "media-skip-forward-symbolic": "media-skip-forward-symbolic.svg",
        "system-shutdown-symbolic": "system-shutdown-symbolic.svg",
        "input-keyboard": "input-keyboard.svg",
        "camera-video-symbolic": "camera-video-symbolic.svg",
        "mic-on": "mic-on.svg",
        "video-display-symbolic": "video-display-symbolic.svg",
    })

    function source(iconName) {
        const override = overrides[iconName];
        if (override) {
            return Qt.resolvedUrl("../assets/icons/" + override);
        }
        return Quickshell.iconPath(iconName, "image-missing");
    }
}
