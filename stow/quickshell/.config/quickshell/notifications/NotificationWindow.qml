import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services as Services

PanelWindow {
    id: root

    required property var screen

    readonly property var shownNotifications: Services.Notifications.notifications
        .slice(Math.max(0, Services.Notifications.notifications.length - StyleNotification.maxVisible))
        .reverse()
    readonly property bool active: Services.Notifications.visible
        && Services.Notifications.screen === root.screen
        && shownNotifications.length > 0

    screen: root.screen
    visible: active
    color: StyleTokens.transparent
    exclusionMode: ExclusionMode.Ignore

    implicitWidth: StyleNotification.width + StyleNotification.dragRunway
    implicitHeight: Math.max(1, notificationList.contentHeight)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notifications"

    anchors {
        bottom: true
        right: true
    }

    margins {
        // The capture preview card owns this corner while it is up, so the
        // stack sits above it rather than under it.
        bottom: StyleShellLayout.notificationBottomMargin
            + Services.CaptureState.captures.length
                * (StyleCapture.cardHeight + StyleNotification.gap)
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
        width: StyleNotification.width
        height: root.height
    }

    Behavior on margins.bottom {
        NumberAnimation {
            duration: StyleTokens.easeDurationFast
            easing.type: StyleTokens.easeStandard
        }
    }

    ListView {
        id: notificationList

        anchors.fill: parent
        spacing: StyleNotification.gap
        interactive: false
        clip: true
        model: ScriptModel {
            values: root.shownNotifications
        }

        // A plain Item takes the delegate slot so the ListView positions this
        // rather than the card: a delegate's own x is owned by the view, and a
        // drag written straight to it does not stick.
        delegate: Item {
            required property var modelData

            width: notificationList.width
            height: card.height

            NotificationCard {
                id: card

                notification: parent.modelData
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

        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: StyleNotification.hideDuration
                easing.type: Easing.InOutCubic
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: StyleNotification.hideDuration
                easing.type: Easing.InCubic
            }
        }
    }
}
