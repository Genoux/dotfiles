import QtQuick
import qs.components
import qs.config
import qs.services

Button {
    id: root
    required property var barWindow

    iconSource: IconRegistry.themeIcon(NotificationCenter.doNotDisturb ? "notifications-disabled-symbolic" : "notification-symbolic")
    interactive: true
    active: popover.open
    onClicked: popover.toggle()
    Accessible.name: "Notifications"

    Connections {
        target: NotificationCenter
        function onToggleRequested(screen) {
            if (screen === root.barWindow.screen)
                popover.toggle()
        }
    }

    BarPopover {
        id: popover
        barWindow: root.barWindow
        anchorItem: root

        NotificationsPopover {
            active: popover.open
            onCollapseRequested: popover.open = false
        }
    }
}
