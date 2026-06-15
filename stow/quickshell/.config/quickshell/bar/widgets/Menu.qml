import qs.components
import qs.services as Services

Button {
    required property var screen

    interactive: true
    iconName: "system-shutdown-symbolic"
    onClicked: Services.PowerMenu.toggleFor(screen)
}
