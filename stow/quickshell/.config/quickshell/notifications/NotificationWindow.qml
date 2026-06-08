import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services as Services

PanelWindow {
    id: root

    required property var screen

    readonly property var shownNotifications: Services.Notifications.notifications
        .slice(Math.max(0, Services.Notifications.notifications.length - Style.notificationMaxVisible))
        .reverse()
    readonly property bool active: Services.Notifications.visible
        && Services.Notifications.screen === root.screen
        && shownNotifications.length > 0

    screen: root.screen
    visible: active
    color: Style.transparent
    exclusionMode: ExclusionMode.Ignore

    implicitWidth: Style.notificationWidth
    implicitHeight: Math.max(1, notificationList.contentHeight)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notifications"

    anchors {
        bottom: true
        right: true
    }

    margins {
        bottom: Style.notificationBottomMargin
        right: Style.notificationRightMargin
    }

    ListView {
        id: notificationList

        anchors.fill: parent
        spacing: Style.notificationGap
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
                duration: Style.notificationShowDuration
                easing.type: Easing.OutCubic
            }
        }

        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Style.notificationHideDuration
                easing.type: Easing.InOutCubic
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Style.notificationHideDuration
                easing.type: Easing.InCubic
            }
        }
    }
}
