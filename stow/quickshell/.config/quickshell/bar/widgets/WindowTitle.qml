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
        const monitor = root.hyprMonitor ? root.hyprMonitor : Hyprland.focusedMonitor
        const special = monitor && monitor.lastIpcObject ? monitor.lastIpcObject.specialWorkspace : null
        if (special && special.id < 0)
            return special.id

        const workspace = monitor && monitor.activeWorkspace ? monitor.activeWorkspace : Hyprland.focusedWorkspace
        return workspace && workspace.id > 0 ? workspace.id : 0
    }

    readonly property var activeToplevel: {
        const focused = Hyprland.activeToplevel
        const toplevel = !root.hyprMonitor || (focused && focused.monitor === root.hyprMonitor)
            ? focused
            : Hyprland.toplevels.values.find((candidate) => candidate.workspace && candidate.workspace.id === visibleWorkspaceId && candidate.monitor === root.hyprMonitor)
        const workspaceId = toplevel && toplevel.workspace ? toplevel.workspace.id : 0
        if (!toplevel || !workspaceId)
            return null

        if (workspaceId === visibleWorkspaceId)
            return toplevel

        if (workspaceId < 0 && toplevel.activated)
            return toplevel

        return null
    }
    readonly property string appIconName: IconRegistry.iconNameForToplevel(activeToplevel)

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
        text: activeToplevel ? activeToplevel.title : ""
        color: Colors.base05
        font.family: Style.fontSans
        font.pixelSize: Style.fontSizeSm
        elide: Text.ElideRight
        Layout.maximumWidth: Style.windowTitleMaxWidth
    }
}
