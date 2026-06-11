import Quickshell
import Quickshell.Wayland
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
        ).slice(0, Style.launcherMaxResults)
    }

    readonly property int surfaceHeight: Style.launcherPadding
        + Style.launcherSearchHeight
        + Style.launcherSpacing
        + panel.listHeight

    readonly property bool active: Services.Launcher.visible && Services.Launcher.screen === root.screen

    property bool displayed: false
    property var closingEntries: []
    property int closingListHeight: panel.listHeight
    property int closingSurfaceHeight: surfaceHeight

    readonly property var visibleEntries: root.active ? root.filteredEntries : root.closingEntries
    readonly property int visibleListHeight: root.active ? panel.listHeight : root.closingListHeight

    OverlayRevealController {
        id: reveal

        active: root.active
        onHideFinished: root.finishHide()
    }

    screen: root.screen
    visible: displayed
    color: Style.transparent
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
            reveal.stopHide()
            displayed = true
            reveal.show()
            Qt.callLater(() => panel.focusSearch())
        } else {
            snapshotClosingLayout()
            reveal.hide()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: Services.Launcher.close()
    }

    Item {
        id: surfaceHost

        width: Style.launcherWidth
        height: root.active ? root.surfaceHeight : root.closingSurfaceHeight
        anchors.centerIn: parent
        scale: reveal.revealScale
        transformOrigin: Item.Center

        Behavior on height {
            NumberAnimation {
                duration: Style.overlayShowDuration
                easing.type: Easing.OutCubic
            }
        }

        OverlayDialogSurface {
            anchors.fill: parent
            revealOpacity: reveal.revealOpacity

            LauncherPanel {
                id: panel

                anchors.fill: parent
                filteredEntries: root.visibleEntries
                active: root.active
                onLaunch: (entry) => root.launchEntry(entry)
                onClose: Services.Launcher.close()
            }
        }
    }

    function launchEntry(entry) {
        if (!entry)
            return

        Services.LauncherHistory.record(entry)
        entry.execute()
        Services.Launcher.close()
    }
}
