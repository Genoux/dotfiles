import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.components

RowLayout {
    id: root

    property var hyprMonitor

    visible: activeToplevel !== null
    spacing: 6

    readonly property int visibleWorkspaceId: {
        const monitor = root.hyprMonitor ?? Hyprland.focusedMonitor
        const special = monitor?.lastIpcObject?.specialWorkspace
        if (special?.id < 0)
            return special.id

        const workspace = monitor?.activeWorkspace ?? Hyprland.focusedWorkspace
        return workspace?.id > 0 ? workspace.id : 0
    }

    readonly property var activeToplevel: {
        const focused = Hyprland.activeToplevel
        const toplevel = !root.hyprMonitor || focused?.monitor === root.hyprMonitor
            ? focused
            : Hyprland.toplevels.values.find((candidate) => candidate.workspace?.id === visibleWorkspaceId && candidate.monitor === root.hyprMonitor)
        const workspaceId = toplevel?.workspace?.id
        if (!toplevel || !workspaceId)
            return null

        if (workspaceId === visibleWorkspaceId)
            return toplevel

        if (workspaceId < 0 && toplevel.activated)
            return toplevel

        return null
    }
    readonly property string appClass: {
        if (!activeToplevel)
            return ""

        const wayland = activeToplevel.wayland
        if (wayland?.appId)
            return wayland.appId

        const ipc = activeToplevel.lastIpcObject
        if (ipc?.class)
            return ipc.class

        return ""
    }
    function desktopEntryForClass(className) {
        const direct = DesktopEntries.heuristicLookup(className)
        if (direct?.icon)
            return direct

        const normalized = className.toLowerCase()
        return DesktopEntries.applications.values.find((entry) => {
            const startup = (entry.startupClass || "").toLowerCase()
            if (startup && (normalized === startup || normalized.includes(startup)))
                return true

            const exec = entry.execString || ""
            const match = exec.match(/--app=(\S+)/)
            if (!match)
                return false

            try {
                const url = new URL(match[1])
                const host = url.hostname.replace(/^www\./, "").toLowerCase()
                const pathKey = url.pathname.replace(/^\/+|\/+$/g, "").replace(/\//g, "_").toLowerCase()
                return (host && normalized.includes(host))
                    || (pathKey && normalized.includes(pathKey))
            } catch (_) {
                return false
            }
        }) ?? null
    }

    readonly property var desktopEntry: desktopEntryForClass(appClass)
    readonly property string appIconName: {
        if (desktopEntry?.icon)
            return desktopEntry.icon
        if (appClass)
            return appClass
        return "application-x-executable"
    }

    IconButton {
        Layout.alignment: Qt.AlignVCenter
        iconName: root.appIconName
        iconSize: Style.iconSizeMd
        implicitWidth: Style.pillHeight
        implicitHeight: Style.pillHeight
        background: Style.transparent
        hoverBackground: Style.transparent
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: activeToplevel?.title ?? ""
        color: Colors.base05
        font.family: Style.fontSans
        font.pixelSize: Style.fontSizeSm
        elide: Text.ElideRight
        Layout.maximumWidth: Style.windowTitleMaxWidth
    }
}
