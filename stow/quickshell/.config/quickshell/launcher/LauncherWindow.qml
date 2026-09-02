import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.components
import qs.config
import qs.services as Services

PanelWindow {
    id: root

    required property var screen

    readonly property string normalizedQuery: Services.Launcher.query.toLowerCase().trim()
    readonly property var filteredEntries: {
        const _ = Services.LauncherHistory.revision
        if (normalizedQuery.length === 0)
            return Services.LauncherHistory.recentEntries()

        return Services.LauncherHistory.sortEntries(
            DesktopEntries.applications.values.filter((entry) => Services.LauncherHistory.matches(entry, normalizedQuery))
        ).slice(0, StyleLauncher.maxResults)
    }

    readonly property int surfaceHeight: StyleLauncher.padding
        + StyleLauncher.searchHeight
        + StyleLauncher.spacing
        + panel.listHeight

    readonly property bool active: Services.Launcher.visible && Services.Launcher.screen === root.screen

    property bool displayed: false
    property var closingEntries: []
    property int closingListHeight: panel.listHeight
    property int closingSurfaceHeight: surfaceHeight

    readonly property var visibleEntries: root.active ? root.filteredEntries : root.closingEntries
    readonly property int visibleListHeight: root.active ? panel.listHeight : root.closingListHeight

    screen: root.screen
    visible: displayed
    color: StyleTokens.transparent
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "launcher"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function snapshotClosingLayout() {
        closingEntries = filteredEntries
        closingListHeight = panel.listHeight
        closingSurfaceHeight = surfaceHeight
    }

    function finishHide() {
        displayed = false
        Services.Launcher.finalizeClose()
    }

    onActiveChanged: {
        if (active) {
            surface.stopHide()
            displayed = true
            surface.show()
            Qt.callLater(() => panel.focusSearch())
        } else {
            snapshotClosingLayout()
            surface.hide()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: Services.Launcher.close()
    }

    OverlayPanel {
        id: surface

        width: StyleLauncher.width
        height: root.active ? root.surfaceHeight : root.closingSurfaceHeight
        anchors.centerIn: parent
        active: root.active
        onHideFinished: root.finishHide()

        Behavior on height {
            NumberAnimation {
                duration: StyleOverlay.showDuration
                easing.type: StyleTokens.easeStandard
            }
        }

        LauncherPanel {
            id: panel

            anchors.fill: parent
            filteredEntries: root.visibleEntries
            active: root.active
            onLaunch: (entry) => root.launchEntry(entry)
            onClose: Services.Launcher.close()
        }
    }

    function launchEntry(entry) {
        if (!entry)
            return

        Services.LauncherHistory.record(entry)
        if (entry.runInTerminal)
            root.launchInTerminal(entry)
        else
            // app2unit rather than entry.execute(): it puts the app in its own
            // app.slice scope, so systemd-oomd can reclaim it individually
            // instead of it inheriting the compositor's session-5.scope.
            Quickshell.execDetached(["app2unit", "--", `${entry.id}.desktop`])
        Services.Launcher.close()
    }

    // TUI apps get one window each: a second launch raises the existing one
    // instead of spawning a duplicate. cliamp writes an IPC socket but only
    // warns on a second instance, so nothing else enforces this.
    function launchInTerminal(entry) {
        const existing = Hyprland.toplevels.values.find(w => w.wayland?.appId === entry.id || w.lastIpcObject?.class === entry.id)
        if (existing?.wayland)
            existing.wayland.activate()
        else
            Quickshell.execDetached(["app2unit", "--", "kitty", "--class", entry.id, "-e", ...entry.command])
    }
}
