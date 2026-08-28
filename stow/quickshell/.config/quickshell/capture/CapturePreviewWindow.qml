import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services as Services

// Bottom-right, the same corner and margins the notification stack uses. The
// notification stack yields upward while this is visible — see
// NotificationWindow.
PanelWindow {
    id: root

    required property var screen

    readonly property bool active: Services.CaptureState.previewVisible
        && Services.CaptureState.screen === root.screen
        && Services.CaptureState.captures.length > 0

    screen: root.screen
    visible: active
    color: StyleTokens.transparent
    exclusionMode: ExclusionMode.Ignore

    implicitWidth: StyleCapture.cardWidth + StyleNotification.dragRunway
    implicitHeight: Math.max(1, cardList.contentHeight)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "capture-preview"

    anchors {
        bottom: true
        right: true
    }

    margins {
        bottom: StyleShellLayout.notificationBottomMargin
        // Negative by the runway so a dragged card has somewhere to go past the
        // output edge. Cards still rest at the usual inset.
        right: StyleShellLayout.notificationRightMargin - StyleNotification.dragRunway
    }

    // Only the resting card column takes pointer input; the runway beside it
    // would otherwise sit over the desktop as an invisible trap. A drag keeps
    // its pointer grab, so a card stays draggable out into the unmasked side.
    mask: Region {
        x: 0
        y: 0
        width: StyleCapture.cardWidth
        height: root.height
    }

    ListView {
        id: cardList

        anchors.fill: parent
        spacing: StyleNotification.gap
        interactive: false
        clip: true
        verticalLayoutDirection: ListView.BottomToTop
        model: ScriptModel {
            values: Services.CaptureState.captures
        }

        // A plain Item takes the delegate slot so the ListView positions this
        // rather than the card: a delegate's own x is owned by the view, and a
        // drag written straight to it does not stick.
        delegate: Item {
            required property string modelData

            width: cardList.width
            height: card.height

            CapturePreviewCard {
                id: card

                path: parent.modelData
            }
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: StyleNotification.showDuration
                easing.type: StyleTokens.easeStandard
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: StyleNotification.hideDuration
                easing.type: StyleTokens.easeStandard
            }
        }

        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: StyleNotification.showDuration
                easing.type: StyleTokens.easeStandard
            }
        }
    }
}
