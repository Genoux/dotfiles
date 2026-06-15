import Quickshell.Services.UPower
import Quickshell
import QtQuick
import qs
import qs.config
import qs.components

Button {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property int percentage: Math.round(device.percentage)
    readonly property bool charging: device.state === UPowerDeviceState.Charging
    readonly property int iconStep: Math.min(Math.floor(percentage / 10) * 10, 100)
    readonly property string iconName: charging && iconStep === 100
        ? "battery-level-100-charged-symbolic"
        : `battery-level-${iconStep}-${charging ? "charging-" : ""}symbolic`

    visible: device.isLaptopBattery
    iconSource: IconRegistry.source(iconName)
    text: `${root.percentage}%`
    foreground: root.percentage <= 15 && !root.charging ? Colors.base08 : Colors.base05
    interactive: true

    onClicked: ShellActions.launchOrFocus("battop", "battop", "gnome-power-manager")
}
