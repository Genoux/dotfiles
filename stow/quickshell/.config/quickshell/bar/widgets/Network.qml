import qs.config
import qs.components
import qs.services as Services

Button {
    readonly property string networkIconName: {
        const icon = Services.Network.connectionIcon
        if (icon === "wireless") return "network-wireless-connected-symbolic"
        if (icon === "wired") return "network-wired-symbolic"
        return "network-offline-symbolic"
    }

    iconName: networkIconName
    interactive: true
    onClicked: ShellActions.launchOrFocus("impala", "impala", "impala")
}
