import qs.config
import qs.components
import qs.services

IconButton {
    id: root

    iconName: Network.connectionIcon
    interactive: true
    onClicked: Launchers.launchOrFocus("impala", "impala", "impala")
}
