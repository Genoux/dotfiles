import qs
import qs.config
import qs.components
import qs.services as Services

Button {
    iconSource: IconRegistry.temperatureIcon(Services.Temperature.icon)
    text: Services.Temperature.value
    interactive: true
    iconTextSpacing: 0
    onClicked: ShellActions.launchOrFocus("btop", "btop", "htop")
}
