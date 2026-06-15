import qs.components
import qs.config
import qs.services as Services

Button {
    required property var screen

    interactive: true
    iconName: "system-search"
    onClicked: Services.Launcher.toggleFor(screen)
}
