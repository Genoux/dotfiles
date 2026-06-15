import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import qs
import qs.config
import qs.components
Row {
    id: root

    property var hyprMonitor

    spacing: StyleWorkspace.rowSpacing

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

    function iconSourceForToplevel(toplevel) {
        const trayItem = trayItemForToplevel(toplevel)
        if (trayItem)
            return trayItem.icon

        return IconRegistry.source(IconRegistry.iconNameForToplevel(toplevel))
    }

    Repeater {
        model: Hyprland.workspaces.values.filter((workspace) => workspace.id > 0 && (!root.hyprMonitor || workspace.monitor === root.hyprMonitor))

        Rectangle {
            id: workspacePill

            required property var modelData
            readonly property var inlineWindows: root.workspaceWindows(modelData)
            readonly property var visibleInlineWindows: inlineWindows.slice(0, StyleWorkspace.inlineMaxIcons)
            readonly property int overflowWindowCount: Math.max(0, inlineWindows.length - StyleWorkspace.inlineMaxIcons)
            readonly property bool showInlineIcons: hovered && inlineWindows.length > 0
            readonly property int pillPaddingH: StyleControl.buttonPaddingHorizontal

            width: showInlineIcons
                ? Math.max(StyleControl.buttonWidth, inlineIconsRow.implicitWidth + StyleWorkspace.inlineIconPadding * 2)
                : Math.max(StyleControl.buttonWidth, workspaceLabel.implicitWidth + pillPaddingH * 2)
            implicitHeight: StyleControl.buttonHeight
            height: implicitHeight
            radius: StyleTokens.radiusSm
            color: mouse.containsMouse ? StyleTokens.alphaLight : StyleTokens.transparent

            Text {
                id: workspaceLabel

                anchors.centerIn: parent
                text: workspacePill.modelData.active ? "●" : workspacePill.modelData.id
                color: workspacePill.modelData.focused ? Colors.base05 : Colors.base04
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
                opacity: workspacePill.showInlineIcons ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: StyleWorkspace.revealDuration
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Row {
                id: inlineIconsRow

                anchors.centerIn: parent
                spacing: StyleWorkspace.inlineIconSpacing
                opacity: workspacePill.showInlineIcons ? 1 : 0
                scale: 0.98 + opacity * 0.02

                Repeater {
                    model: ScriptModel {
                        values: workspacePill.visibleInlineWindows
                    }

                    IconImage {
                        required property var modelData

                        width: StyleWorkspace.inlineIconSize
                        height: StyleWorkspace.inlineIconSize
                        implicitSize: StyleWorkspace.inlineIconSize
                        source: root.iconSourceForToplevel(modelData)
                    }
                }

                Text {
                    visible: workspacePill.overflowWindowCount > 0
                    text: `+${workspacePill.overflowWindowCount}`
                    color: Colors.base04
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeXs
                    anchors.verticalCenter: parent.verticalCenter
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: StyleWorkspace.revealDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: StyleWorkspace.revealDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: ShellActions.switchWorkspace(workspacePill.modelData)
            }

            readonly property bool hovered: mouse.containsMouse

            Behavior on color {
                ColorAnimation {
                    duration: StyleTokens.easeDurationFast
                    easing.type: Easing.InOutQuad
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: StyleWorkspace.revealDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
