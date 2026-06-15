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

    implicitWidth: StyleNotification.width
    implicitHeight: Math.max(1, notificationList.contentHeight)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notifications"

    anchors {
        bottom: true
        right: true
    }

    margins {
        bottom: StyleShellLayout.notificationBottomMargin
        right: StyleShellLayout.notificationRightMargin
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

        delegate: NotificationCard {
            required property var modelData

            width: notificationList.width
            notification: modelData
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: StyleNotification.showDuration
                easing.type: Easing.OutCubic
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
