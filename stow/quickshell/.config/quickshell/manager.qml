//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.manager

ShellRoot {
    id: root
    property bool opened: false
    property var targetScreen: null
    // Layer-shell overlays sit above polkit's normal toplevel authentication window.
    readonly property bool authenticationOpen: managerState.busy && Hyprland.toplevels.values.some(toplevel =>
        /polkit|policykit|authentication-agent/i.test(toplevel.wayland?.appId || toplevel.lastIpcObject?.class || ""))

    function open() {
        targetScreen = ShellActions.focusedScreen()
        opened = true
        managerState.refresh()
    }

    Component.onCompleted: Qt.callLater(open)

    ManagerState { id: managerState }

    IpcHandler {
        target: "manager"
        function open(): void { root.open() }
        function close(): void { root.opened = false }
    }

    Backdrop {
        screen: root.targetScreen
        active: root.opened && !root.authenticationOpen
        layerNamespace: "workspace-manager-backdrop"
        onDismissed: root.opened = false
    }

    PanelWindow {
        id: window
        screen: root.targetScreen
        property bool displayed: false
        visible: displayed && !root.authenticationOpen
        onVisibleChanged: if (visible) Qt.callLater(() => panel.forceActiveFocus())
        color: StyleTokens.transparent
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "workspace-manager"
        anchors { top: true; bottom: true; left: true; right: true }

        Connections {
            target: root
            function onOpenedChanged() {
                if (root.opened) {
                    window.displayed = true
                    surface.stopHide()
                    surface.show()
                    Qt.callLater(() => panel.forceActiveFocus())
                } else {
                    surface.hide()
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.opened = false
        }
        OverlayPanel {
            id: surface
            anchors.centerIn: parent
            width: Math.min(StyleManager.width, Math.max(0, window.width - StyleManager.margin))
            height: Math.min(StyleManager.height, Math.max(0, window.height - StyleManager.margin))
            active: root.opened
            onHideFinished: {
                window.displayed = false
                Qt.quit()
            }
            MouseArea { anchors.fill: parent }
            ManagerPanel {
                id: panel
                anchors.fill: parent
                manager: managerState
                onCloseRequested: root.opened = false
            }
        }
    }
}
