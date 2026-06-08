import qs
import qs.config
import qs.components
import qs.services as Services

InfoPill {
    iconText: "󰔏"
    labelText: Services.Temperature.value
    onClicked: ShellActions.launchOrFocus("btop", "btop", "htop")
}
