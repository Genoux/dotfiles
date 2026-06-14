pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property var overrides: ({
        "emblem-favorite-symbolic": "emblem-favorite-symbolic.svg",
        "network-wireless-symbolic": "network-wireless-symbolic.svg",
        "network-idle-symbolic": "network-idle-symbolic.svg",
        "network-offline-symbolic": "network-offline-symbolic.svg",
        "audio-volume-high-symbolic": "audio-volume-high-symbolic.svg",
        "audio-volume-medium-symbolic": "audio-volume-medium-symbolic.svg",
        "audio-volume-low-symbolic": "audio-volume-low-symbolic.svg",
        "audio-volume-muted-symbolic": "audio-volume-muted-symbolic.svg",
        "bluetooth-active-symbolic": "bluetooth-active-symbolic.svg",
        "media-record-symbolic": "media-record-symbolic.svg",
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

    function hasOverride(iconName) {
        return overrides[iconName] !== undefined;
    }

    function source(iconName) {
        const override = overrides[iconName];
        if (override) {
            return Qt.resolvedUrl("../assets/icons/" + override);
        }
        return Quickshell.iconPath(iconName, "image-missing");
    }

    function className(toplevel) {
        if (!toplevel)
            return "";

        const wayland = toplevel.wayland;
        if (wayland && wayland.appId)
            return wayland.appId;

        const ipc = toplevel.lastIpcObject;
        if (ipc && ipc.class)
            return ipc.class;

        if (ipc && ipc.initialClass)
            return ipc.initialClass;

        return "";
    }

    function desktopEntryForClass(className) {
        if (!className)
            return null;

        const direct = DesktopEntries.heuristicLookup(className);
        if (direct && direct.icon)
            return direct;

        const normalized = className.toLowerCase();
        return DesktopEntries.applications.values.find((entry) => {
            const startup = (entry.startupClass || "").toLowerCase();
            if (startup && (normalized === startup || normalized.includes(startup)))
                return true;

            const exec = entry.execString || "";
            const match = exec.match(/--app=(\S+)/);
            if (!match)
                return false;

            try {
                const url = new URL(match[1]);
                const host = url.hostname.replace(/^www\./, "").toLowerCase();
                const pathKey = url.pathname.replace(/^\/+|\/+$/g, "").replace(/\//g, "_").toLowerCase();
                return (host && normalized.includes(host))
                    || (pathKey && normalized.includes(pathKey));
            } catch (_) {
                return false;
            }
        }) || null;
    }

    function iconNameForToplevel(toplevel) {
        const appClass = className(toplevel);
        const desktopEntry = desktopEntryForClass(appClass);
        if (desktopEntry && desktopEntry.icon)
            return desktopEntry.icon;

        if (appClass)
            return appClass;

        return "application-x-executable";
    }
}
