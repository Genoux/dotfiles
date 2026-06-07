import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.config
import qs.components

Row {
    id: root
    
    visible: activeToplevel !== null
    spacing: 2

    readonly property int visibleWorkspaceId: {
        const monitor = Hyprland.focusedMonitor
        const special = monitor?.lastIpcObject?.specialWorkspace
        if (special?.id < 0)
            return special.id

        const workspace = Hyprland.focusedWorkspace
        return workspace?.id > 0 ? workspace.id : 0
    }

    readonly property var activeToplevel: {
        const toplevel = Hyprland.activeToplevel
        const workspaceId = toplevel?.workspace?.id
        if (!toplevel || !workspaceId)
            return null

        if (workspaceId === visibleWorkspaceId)
            return toplevel

        // Special overlay keeps focusedWorkspace on the regular workspace underneath
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
    readonly property var desktopEntry: DesktopEntries.heuristicLookup(appClass)
    readonly property string appIconName: {
        if (desktopEntry?.icon)
            return desktopEntry.icon
        if (appClass)
            return appClass
        return "application-x-executable"
    }

    IconButton {
        iconName: root.appIconName
        iconSize: 18
        background: Style.transparent
        hoverBackground: Style.transparent
    }

    Text {
        text: activeToplevel?.title ?? ""
        color: Colors.base05
        font.family: Style.fontSans
        font.pixelSize: 13
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 420)
    }
}
