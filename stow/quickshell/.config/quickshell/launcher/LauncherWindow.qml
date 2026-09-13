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
    readonly property var filteredEntries: Services.LauncherHistory.search(normalizedQuery, StyleLauncher.maxResults)

    readonly property int surfaceHeight: StyleLauncher.padding
        + StyleLauncher.searchHeight
        + StyleLauncher.spacing
        + panel.listHeight

    readonly property bool active: Services.Launcher.visible && Services.Launcher.screen === root.screen

    property bool displayed: false
    property string pendingHistoryId: ""

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

    function finishHide() {
        displayed = false
        recordPendingLaunch()
        Services.Launcher.finalizeClose()
    }

    function recordPendingLaunch() {
        if (!pendingHistoryId)
            return

        Services.LauncherHistory.record(DesktopEntries.byId(pendingHistoryId))
        pendingHistoryId = ""
    }

    onActiveChanged: {
        if (active) {
            surface.stopHide()
            recordPendingLaunch()
            panel.resetScroll()
            displayed = true
            surface.show()
            Qt.callLater(() => panel.focusSearch())
        } else {
            surface.hide()
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: Services.Launcher.close()
    }

    OverlayPanel {
        id: surface

        width: StyleLauncher.width
        height: root.surfaceHeight
        anchors.centerIn: parent
        active: root.active
        onHideFinished: root.finishHide()

        LauncherPanel {
            id: panel

            anchors.fill: parent
            filteredEntries: root.filteredEntries
            active: root.active
            onLaunch: (entry) => root.launchEntry(entry)
            onClose: Services.Launcher.close()
        }
    }

    function launchEntry(entry) {
        if (!entry || !active)
            return

        // Updating history reorders the model, so wait until the panel is hidden.
        pendingHistoryId = entry.id
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
