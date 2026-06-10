import Quickshell
import Quickshell.Bluetooth
import qs.components
import qs.config

IconButton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter

    readonly property bool hasConnectedDevice: (adapter?.devices?.values ?? []).some(d => d.connected)

    visible: adapter?.enabled ?? false
    iconName: hasConnectedDevice ? "bluetooth-active-symbolic" : "bluetooth-symbolic"
    interactive: true
    onClicked: ShellActions.launchOrFocus("bluetui", "bluetui", "bluetooth")
}
