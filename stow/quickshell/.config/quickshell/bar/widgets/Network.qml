import qs.components
import qs.config
import qs.services as Services

Button {
    readonly property string networkIconKey: {
        const type = Services.Network.linkType;
        const online = Services.Network.isOnline;
        if (type === "wireless")
            return online ? "wireless" : "wireless-offline";

        if (type === "wired")
            return online ? "wired" : "wired-offline";

        return online ? "wired" : "offline";
    }

    iconSource: IconRegistry.networkIcon(networkIconKey)
    interactive: true
    onClicked: ShellActions.launchOrFocus("impala", "impala", "impala")
}
