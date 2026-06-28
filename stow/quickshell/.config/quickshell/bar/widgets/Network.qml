import qs.components
import qs.config
import qs.services as Services

Button {
    readonly property string networkIconName: {
        const type = Services.Network.linkType;
        const online = Services.Network.isOnline;
        if (type === "wireless")
            return online ? "wireless-symbolic" : "wireless-offline-symbolic";

        if (type === "wired")
            return online ? "wired-symbolic" : "offline-symbolic";

        return online ? "wired-symbolic" : "offline-symbolic";
    }

    iconName: networkIconName
    interactive: true
    onClicked: ShellActions.launchOrFocus("impala", "impala", "impala")
}
