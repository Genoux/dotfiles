pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import qs.config

Singleton {
    id: root

    readonly property var notifications: server.trackedNotifications.values
    readonly property bool visible: notifications.length > 0

    property var screen: null

    signal refreshed(var notification)

    function track(notification) {
        if (!notification)
            return

        root.screen = ShellActions.focusedScreen()
        notification.tracked = true
        root.refreshed(notification)
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

    // How long a notification stays up, in ms; 0 keeps it until dismissed.
    function expiryMs(notification) {
        if (notification?.urgency === NotificationUrgency.Critical)
            return 0
        const requestedTimeout = Number(notification?.expireTimeout ?? -1)
        if (!Number.isFinite(requestedTimeout) || requestedTimeout < 0)
            return StyleNotification.timeout

        // Quickshell 0.3.0 notification.cpp stores the DBus milliseconds unchanged.
        return requestedTimeout
    }

    // The notification's default action, or failing that its app.
    function activate(notification) {
        const actions = notification?.actions ?? []
        const action = actions.find((candidate) => candidate.identifier === "default")

        if (action) {
            action.invoke()
            return
        }

        const entryId = notification?.desktopEntry ?? ""
        if (entryId.length === 0)
            return

        const normalizedId = entryId.endsWith(".desktop") ? entryId : `${entryId}.desktop`
        const entry = DesktopEntries.applications.values.find((candidate) => {
            return candidate.id === entryId
                || candidate.id === normalizedId
                || candidate.id.replace(/\.desktop$/, "") === entryId
        })

        entry?.execute()
    }

    function namedActions(notification) {
        return (notification?.actions ?? []).filter(action => action.identifier !== "default" && action.identifier !== "")
    }

    function cleanText(value) {
        return (value ?? "").toString().replace(/\s+/g, " ").trim()
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
