import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.components

Item {
    id: root

    property var hyprMonitor
    property real availableWidth: implicitWidth

    visible: activeToplevel !== null
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    clip: true

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

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.availableWidth)
        spacing: StyleTokens.space6

        Behavior on width {
            NumberAnimation {
                duration: StyleTokens.easeDurationNormal
                easing.type: StyleTokens.easeStandard
            }
        }

        Button {
            Layout.alignment: Qt.AlignVCenter
            iconName: root.appIconName
            iconSize: StyleControl.iconSizeMd
            background: StyleTokens.transparent
            hoverBackground: StyleTokens.transparent
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.maximumWidth: StyleBar.windowTitleMaxWidth
            text: activeToplevel ? activeToplevel.title : ""
            color: Colors.base05
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleBar.labelFontSize
            elide: Text.ElideRight
        }
    }
}
