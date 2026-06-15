import qs
import qs.config
import qs.components
import qs.services as Services

Button {
    iconGlyph: "󰔏"
    text: Services.Temperature.value
    interactive: true
    onClicked: ShellActions.launchOrFocus("btop", "btop", "htop")
}
