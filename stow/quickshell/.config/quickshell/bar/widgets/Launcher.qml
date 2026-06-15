import qs.components
import qs.services as Services

Button {
    required property var screen

    interactive: true
    iconName: "system-search-symbolic"
    onClicked: Services.Launcher.toggleFor(screen)
}
