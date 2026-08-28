import qs.components
import qs.config
import qs.services as Services

Button {
    required property var screen

    interactive: true
    iconSource: IconRegistry.barControlIcon("launcher")
    onClicked: Services.Launcher.toggleFor(screen)
}
