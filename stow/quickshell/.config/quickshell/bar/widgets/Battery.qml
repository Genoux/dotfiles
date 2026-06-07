import Quickshell.Services.UPower
import Quickshell
import Quickshell.Widgets
import QtQuick
import qs
import qs.config
Rectangle {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property int percentage: Math.round(device.percentage)
    readonly property bool charging: device.state === UPowerDeviceState.Charging
    readonly property int iconStep: Math.min(Math.floor(percentage / 10) * 10, 100)
    readonly property string iconName: charging && iconStep === 100
        ? "battery-level-100-charged-symbolic"
        : `battery-level-${iconStep}-${charging ? "charging-" : ""}symbolic`

    visible: device.isLaptopBattery
    implicitWidth: content.implicitWidth + 8
    implicitHeight: Style.pillHeight
    radius: Style.radiusSm
    color: mouse.containsMouse ? Style.alphaLight : Style.transparent

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 2

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.iconSizeXs
            height: Style.iconSizeXs
            source: IconRegistry.source(root.iconName)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: `${root.percentage}%`
            color: root.percentage <= 15 && !root.charging ? Colors.base08 : Colors.base05
            font.family: Style.fontSans
            font.pixelSize: Style.fontSizeSm
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Launchers.launchOrFocus("battop", "battop", "gnome-power-manager")
    }
}
