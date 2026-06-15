import qs.config
import qs.components
import qs.services as Services

Button {
    iconName: Services.Network.connectionIcon
    interactive: true
    onClicked: ShellActions.launchOrFocus("impala", "impala", "impala")
}
