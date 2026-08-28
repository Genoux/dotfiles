import qs.components
import qs.config
import qs.services as Services

Button {
    required property var screen

    interactive: true
    active: Services.ComponentGallery.visible && Services.ComponentGallery.screen === screen
    // First-party bar controls share the normalized bundled icon grid.
    iconSource: IconRegistry.barControlIcon("components")
    onClicked: Services.ComponentGallery.toggleFor(screen)
}
