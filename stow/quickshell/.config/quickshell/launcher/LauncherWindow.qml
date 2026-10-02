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
    readonly property var filteredEntries: Services.LauncherHistory.search(normalizedQuery, StyleLauncher.maxResults)

    readonly property int surfaceHeight: StyleLauncher.padding
        + StyleLauncher.searchHeight
        + StyleLauncher.spacing
        + panel.listHeight

    readonly property bool active: Services.Launcher.visible && Services.Launcher.screen === root.screen

    property bool displayed: false

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
        Services.Launcher.recordPendingLaunch()
        Services.Launcher.finalizeClose()
    }

    onActiveChanged: {
        if (active) {
            surface.stopHide()
            Services.Launcher.recordPendingLaunch()
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
            onLaunch: (entry) => {
                if (!entry || !root.active)
                    return

                Services.Launcher.launch(entry)
                Services.Launcher.close()
            }
            onClose: Services.Launcher.close()
        }
    }
}
