import qs.components
import qs.services as Services

IconButton {
    id: root

    required property var screen

    interactive: true
    iconName: "system-shutdown-symbolic"
    onClicked: Services.PowerMenu.toggleFor(root.screen)
}
