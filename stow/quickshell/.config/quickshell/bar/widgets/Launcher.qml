import QtQuick
import qs.components
import qs.services as Services

IconButton {
    id: root

    required property var screen

    interactive: true
    iconName: "system-search-symbolic"
    onClicked: Services.Launcher.toggleFor(root.screen)
}
