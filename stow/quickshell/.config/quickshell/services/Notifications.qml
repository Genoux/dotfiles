pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property var notifications: server.trackedNotifications.values
    readonly property bool visible: notifications.length > 0

    property var screen: null

    function focusedScreen() {
        const monitor = Hyprland.focusedMonitor
        if (!monitor)
            return Quickshell.screens[0] ?? null

        return Quickshell.screens.find((candidate) => {
            const hyprMonitor = Hyprland.monitorFor(candidate)
            return hyprMonitor === monitor || hyprMonitor?.name === monitor?.name
        }) ?? Quickshell.screens[0] ?? null
    }

    function track(notification) {
        if (!notification)
            return

        root.screen = root.focusedScreen()
        notification.tracked = true
    }

    function dismiss(notification) {
        if (notification)
            notification.dismiss()
    }

    function expire(notification) {
        if (notification)
            notification.expire()
    }

    function dismissAll() {
        server.trackedNotifications.values.slice().forEach((notification) => notification.dismiss())
    }

    NotificationServer {
        id: server

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        keepOnReload: false
        persistenceSupported: false

        onNotification: (notification) => root.track(notification)
    }
}
