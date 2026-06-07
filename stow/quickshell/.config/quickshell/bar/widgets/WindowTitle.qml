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
    readonly property var desktopEntry: DesktopEntries.heuristicLookup(appClass)
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
