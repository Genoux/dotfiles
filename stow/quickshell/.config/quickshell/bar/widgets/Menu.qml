import qs.components
import qs.config
import qs.services as Services

Button {
    required property var screen

    interactive: true
    iconSource: IconRegistry.barIcon("menu", "shutdown")
    onClicked: Services.PowerMenu.toggleFor(screen)
}
