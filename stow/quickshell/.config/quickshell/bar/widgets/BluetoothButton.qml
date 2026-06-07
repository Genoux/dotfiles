import Quickshell
import Quickshell.Bluetooth
import qs.components

IconButton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter

    visible: adapter?.enabled ?? false
    iconName: "bluetooth-symbolic"
    interactive: true
    onClicked: Quickshell.execDetached(["blueman-manager"])
}
