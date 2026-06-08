import qs
import qs.config
import qs.components
import qs.services

InfoPill {
    iconText: "󰔏"
    labelText: Temperature.value
    onClicked: Launchers.launchOrFocus("btop", "btop", "htop")
}
