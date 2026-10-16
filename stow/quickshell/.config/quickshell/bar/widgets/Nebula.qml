import qs
import qs.components
import qs.config
import qs.services as Services

Button {
    interactive: true
    active: Services.Nebula.active
    iconSource: IconRegistry.barControlIcon("nebula")
    onClicked: Services.Nebula.toggle()
}
