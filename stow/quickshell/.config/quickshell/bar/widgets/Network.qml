import qs.components
import qs.config
import qs.services as Services

Button {
    readonly property string networkIconName: {
        const type = Services.Network.linkType;
        const online = Services.Network.isOnline;
        if (type === "wireless")
            return online ? "network-wireless-signal-excellent-symbolic" : "network-wireless-offline-symbolic";

        if (type === "wired")
            return online ? "network-wired-symbolic" : "network-wired-disconnected-symbolic";

        return online ? "network-wired-symbolic" : "network-offline-symbolic";
    }

    iconName: networkIconName
    interactive: true
    iconSize: 14
    onClicked: ShellActions.launchOrFocus("impala", "impala", "impala")
}
