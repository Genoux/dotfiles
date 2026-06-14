import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.config
import qs.components
Row {
    id: root

    property var hyprMonitor
    property var panelWindow
    property var hoveredWorkspace: null
    property var hoveredPill: null
    property var pendingWorkspace: null
    property var pendingPill: null
    property real popupCenterX: 0

    readonly property int workspacePreviewHoverDelay: 250
    readonly property int workspacePreviewHideDelay: 120
    readonly property int workspacePreviewShowDuration: 110
    readonly property int workspacePreviewPadding: 4
    readonly property int workspacePreviewIconPadding: 2
    readonly property int workspacePreviewIconSize: 14
    readonly property color workspacePreviewSurface: Qt.rgba(0, 0, 0, 0.16)
    readonly property real workspacePreviewBorderOpacity: 0.07
    readonly property color workspacePreviewBorder: Qt.rgba(Colors.base04.r, Colors.base04.g, Colors.base04.b, workspacePreviewBorderOpacity)

    readonly property var hoveredWindows: workspaceWindows(hoveredWorkspace)
    readonly property bool popupVisible: hoveredWorkspace !== null
        && hoveredWindows.length > 0
        && Boolean(panelWindow)

    spacing: 2

    function workspaceWindows(workspace) {
        if (!workspace || !workspace.toplevels || !workspace.toplevels.values)
            return []

        return workspace.toplevels.values.filter((toplevel) => {
            return toplevel && toplevel.workspace && toplevel.workspace.id === workspace.id
        })
    }

    function normalizedTokens(values) {
        const seen = {}
        const tokens = []

        for (const value of values) {
            const normalized = String(value || "").toLowerCase().trim()
            const parts = [normalized].concat(normalized.split(/[._\s-]+/))

            for (const token of parts) {
                if (token.length <= 2 || seen[token])
                    continue

                seen[token] = true
                tokens.push(token)
            }
        }

        return tokens
    }

    function trayItemForToplevel(toplevel) {
        if (!toplevel)
            return null

        const ipc = toplevel.lastIpcObject || {}
        const windowTokens = normalizedTokens([
            IconRegistry.className(toplevel),
            ipc.initialClass,
            toplevel.title
        ])

        if (!windowTokens.length)
            return null

        return SystemTray.items.values.find((item) => {
            const trayTokens = normalizedTokens([item.id, item.title, item.tooltipTitle])
            return windowTokens.some((windowToken) => {
                return trayTokens.some((trayToken) => {
                    return windowToken === trayToken
                        || windowToken.includes(trayToken)
                        || trayToken.includes(windowToken)
                })
            })
        }) || null
    }

    function showWorkspace(workspace, item) {
        hideTimer.stop()
        pendingWorkspace = workspace
        pendingPill = item

        if (hoveredWorkspace !== workspace) {
            hoveredWorkspace = null
            hoveredPill = null
        }

        const position = item.mapToItem(null, item.width / 2, 0)
        popupCenterX = position.x
        showTimer.restart()
    }

    function scheduleHide(item) {
        showTimer.stop()
        pendingWorkspace = null
        pendingPill = null

        if (hoveredPill === item)
            hoveredPill = null

        hideTimer.restart()
    }

    function focusWindow(toplevel) {
        if (toplevel && toplevel.wayland)
            toplevel.wayland.activate()
        else if (toplevel && toplevel.address)
            ShellActions.focusWindow(`address:${toplevel.address}`)

        showTimer.stop()
        hoveredWorkspace = null
        hoveredPill = null
        pendingWorkspace = null
        pendingPill = null
    }

    Timer {
        id: showTimer

        interval: root.workspacePreviewHoverDelay
        onTriggered: {
            if (!pendingPill || !pendingPill.hovered || !pendingWorkspace)
                return

            hoveredWorkspace = pendingWorkspace
            hoveredPill = pendingPill
        }
    }

    Timer {
        id: hideTimer

        interval: root.workspacePreviewHideDelay
        onTriggered: {
            if (hoveredPill || popupHover.hovered)
                return

            hoveredWorkspace = null
        }
    }

    Repeater {
        model: Hyprland.workspaces.values.filter((workspace) => workspace.id > 0 && (!root.hyprMonitor || workspace.monitor === root.hyprMonitor))

        Pill {
            id: workspacePill

            required property var modelData

            text: modelData.active ? "●" : modelData.id
            foreground: modelData.focused ? Colors.base05 : Colors.base04
            background: Style.transparent
            hoverBackground: Style.alphaLight
            width: 22
            horizontalPadding: 4
            fontSize: 12
            interactive: true
            onClicked: ShellActions.switchWorkspace(modelData)
            onHoveredChanged: {
                if (hovered)
                    root.showWorkspace(modelData, workspacePill)
                else
                    root.scheduleHide(workspacePill)
            }

            Behavior on fontSize {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }

    PopupWindow {
        id: workspacePopover

        readonly property real preferredX: root.popupCenterX - width / 2
        readonly property real maxX: Math.max(0, (root.panelWindow ? root.panelWindow.width : 0) - width - Style.barMargin)

        anchor.window: root.panelWindow
        anchor.rect.x: Math.max(Style.barMargin, Math.min(preferredX, maxX))
        anchor.rect.y: -height - 2
        implicitWidth: iconsRow.implicitWidth + root.workspacePreviewPadding * 2
        implicitHeight: 30
        visible: root.popupVisible
        color: Style.transparent

        HoverHandler {
            id: popupHover

            onHoveredChanged: {
                if (hovered)
                    hideTimer.stop()
                else
                    root.scheduleHide(null)
            }
        }

        Rectangle {
            id: previewSurface

            anchors.fill: parent
            radius: Style.radiusMd
            color: root.workspacePreviewSurface
            border.width: 1
            border.color: root.workspacePreviewBorder
            opacity: root.popupVisible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: root.workspacePreviewShowDuration
                    easing.type: Easing.OutQuad
                }
            }

            Row {
                id: iconsRow

                anchors.centerIn: parent
                spacing: 1
                scale: 0.98 + previewSurface.opacity * 0.02

                Behavior on scale {
                    NumberAnimation {
                        duration: root.workspacePreviewShowDuration
                        easing.type: Easing.OutQuad
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values: root.hoveredWindows
                    }

                    IconButton {
                        required property var modelData
                        readonly property var trayItem: root.trayItemForToplevel(modelData)

                        iconSource: trayItem ? trayItem.icon : ""
                        iconName: trayItem ? "" : IconRegistry.iconNameForToplevel(modelData)
                        foreground: modelData.urgent ? Colors.base0A : (modelData.activated ? Colors.base05 : Colors.base04)
                        background: Style.transparent
                        hoverBackground: Style.alphaLight
                        width: root.workspacePreviewIconSize + root.workspacePreviewIconPadding * 2
                        height: root.workspacePreviewIconSize + root.workspacePreviewIconPadding * 2
                        iconSize: root.workspacePreviewIconSize
                        interactive: true
                        onClicked: root.focusWindow(modelData)
                    }
                }
            }
        }
    }
}
