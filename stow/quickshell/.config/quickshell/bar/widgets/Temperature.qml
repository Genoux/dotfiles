import qs
import qs.config
import qs.components
import qs.services as Services

Button {
    iconSource: IconRegistry.temperatureIcon(Services.Temperature.icon)
    text: Services.Temperature.value
    fontSize: StyleBar.labelFontSize
    interactive: true
    iconTextSpacing: StyleControl.iconTextSpacing
    onClicked: ShellActions.launchOrFocus("btop", "btop", "htop")
}
