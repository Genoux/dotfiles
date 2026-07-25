import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.components
import qs.config

Button {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool adapterEnabled: adapter?.enabled ?? false

    iconName: adapterEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
    interactive: true
    onClicked: ShellActions.launchOrFocus("bluetui", "bluetui", "bluetooth")
}
