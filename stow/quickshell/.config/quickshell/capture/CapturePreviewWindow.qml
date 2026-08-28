import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services as Services

// Bottom-right, the same corner and margins the notification stack uses. The
// stack yields upward while this is visible — see NotificationWindow.
PanelWindow {
    id: root

    required property var screen

    readonly property bool active: Services.CaptureState.previewVisible
        && Services.CaptureState.screen === root.screen
        && Services.CaptureState.latestPath.length > 0

    screen: root.screen
    visible: active
    color: StyleTokens.transparent
    exclusionMode: ExclusionMode.Ignore

    implicitWidth: StyleCapture.cardWidth
    implicitHeight: Math.max(1, card.height)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "capture-preview"

    anchors {
        bottom: true
        right: true
    }

    margins {
        bottom: StyleShellLayout.notificationBottomMargin
        right: StyleShellLayout.notificationRightMargin
    }

    CapturePreviewCard {
        id: card

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }
}
