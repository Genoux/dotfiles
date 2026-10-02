import QtQuick
import qs.components
import qs.config
import qs.services as Services

Button {
    id: root

    required property var barWindow

    iconSource: IconRegistry.networkIcon(Services.Network.iconKey)
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
