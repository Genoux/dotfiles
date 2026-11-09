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

    // The notification's default action, or failing that its app: a window
    // already open is raised rather than a second instance launched. Also
    // takes a stored history entry, which has no actions left to invoke.
    function activate(notification) {
        const actions = notification?.actions ?? []
        const action = actions.find((candidate) => candidate.identifier === "default")

        if (action) {
            action.invoke()
            return
        }

        // The icon's own lookup first, so the app raised is the one the icon
        // shows; it skips entries without an icon, which the plain id match
        // after it still finds.
        const entryHint = (value) => String(value ?? "").replace(/\.desktop$/, "")
        const desktopHint = entryHint(notification?.desktopEntry)
        const entry = IconRegistry.declaredEntry(desktopHint)
            ?? IconRegistry.declaredEntry(entryHint(notification?.appIcon))
            ?? (desktopHint ? DesktopEntries.applications.values.find((candidate) => candidate.id.replace(/\.desktop$/, "") === desktopHint) : null)
        const window = ShellActions.findToplevel(entry?.startupClass || entry?.id || "", notification?.appName ?? "")

        if (window?.wayland) {
            window.wayland.activate()
            return
        }

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

        // Left untracked, a notification is closed at once and never pops up.
        // Do not disturb still lets a critical one through: a dying battery.
        // Tracked before it is recorded, so a history failure cannot cost the popup.
        onNotification: (notification) => {
            if (!NotificationCenter.doNotDisturb || notification.urgency === NotificationUrgency.Critical)
                root.track(notification)
            NotificationCenter.record(notification)
        }
    }
}
