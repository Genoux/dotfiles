import QtQuick
import qs.components
import qs.config
import qs.services as Services

Button {
    id: root

    required property var barWindow

    // The bar states which link is carrying traffic, not how strong it is —
    // strength is a comparison, and comparing belongs in the panel. Bundled
    // marks keep this button tinted with the rest of the bar rather than
    // adopting an icon theme's own colours.
    readonly property var networkIconSource: {
        const type = Services.Network.linkType;
        const online = Services.Network.isOnline;
        if (type === "wireless")
            return IconRegistry.networkIcon(online ? "wireless" : "wireless-offline");

        if (type === "wired")
            return IconRegistry.networkIcon(online ? "wired" : "wired-offline");

        return IconRegistry.networkIcon(online ? "wired" : "offline");
    }

    iconSource: networkIconSource
    interactive: true
    active: popover.open
    onClicked: popover.toggle()

    BarPopover {
        id: popover

        barWindow: root.barWindow
        anchorItem: root
        // Only while a passphrase field is open. A panel that held the keyboard
        // for its whole visit would take keystrokes away from the focused
        // window just for showing which network is connected.
        acceptsKeyboard: Services.WifiState.passphrasePath.length > 0

        NetworkPopover {
            active: popover.open
        }
    }
}
