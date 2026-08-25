import QtQuick
import Quickshell
import Quickshell.Bluetooth as Bluez
import qs
import qs.components
import qs.config
import qs.services

Rectangle {
    id: row

    required property var device

    readonly property bool busy: device.pairing
        || device.state === Bluez.BluetoothDeviceState.Connecting
        || device.state === Bluez.BluetoothDeviceState.Disconnecting
    readonly property string displayName: {
        const named = String(device.name || device.deviceName || "").trim()
        return named.length > 0 ? named : device.address
    }
    readonly property string statusText: {
        if (device.pairing)
            return "Pairing…"
        if (device.state === Bluez.BluetoothDeviceState.Connecting)
            return "Connecting…"
        if (device.state === Bluez.BluetoothDeviceState.Disconnecting)
            return "Disconnecting…"
        if (device.blocked)
            return "Blocked"
        if (device.connected && device.batteryAvailable)
            return "Connected · " + Math.round(device.battery * 100) + "%"
        if (device.connected)
            return "Connected"
        if (device.paired)
            return "Paired"
        return "Not paired"
    }
    // BlueZ reports a Freedesktop icon name per device class. Fall back to the
    // bundled Bluetooth mark when the theme has nothing for it, rather than
    // leaving a hole in the row.
    readonly property var deviceIconSource: {
        const name = String(device.icon || "").trim()
        if (!name)
            return IconRegistry.bluetoothIcon(true)

        const themed = Quickshell.iconPath(name, true)
        return String(themed).length > 0 ? themed : IconRegistry.bluetoothIcon(true)
    }

    implicitHeight: StylePopover.listRowHeight
    height: implicitHeight
    radius: StyleTokens.radiusSm
    color: hover.hovered ? StyleTokens.alphaLight : StyleTokens.transparent
    opacity: device.blocked ? 0.4 : 1

    // Leaving the row drops the forget confirmation. Without this the button
    // stays confirming behind opacity 0, so the next hover would forget on one
    // click with no warning shown — worse than having no confirmation at all.
    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (!hovered)
                forgetButton.confirming = false
        }
    }

    ThemedIcon {
        id: deviceIcon

        anchors.left: parent.left
        anchors.leftMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
        anchors.verticalCenter: parent.verticalCenter
        source: row.deviceIconSource
    }

    Column {
        anchors.left: deviceIcon.right
        anchors.leftMargin: 10
        anchors.right: forgetButton.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: row.displayName
            color: Colors.base05
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeSm
            font.weight: row.device.connected ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: row.statusText
            color: Colors.base04
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeXs
            elide: Text.ElideRight
        }
    }

    // Forgetting is destructive and rare, so it stays out of the row until the
    // pointer is on it. Declared above the row's own MouseArea so its click
    // lands here instead of toggling the connection underneath. The glyph keeps
    // the resting row quiet; the confirm step spells the word out because
    // removing the pairing also drops the trust flag and link keys, and getting
    // the device back needs it put into pairing mode again.
    PillButton {
        id: forgetButton

        property bool confirming: false

        z: 1
        anchors.right: parent.right
        anchors.rightMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
        anchors.verticalCenter: parent.verticalCenter
        visible: row.device.paired && !row.busy
        opacity: hover.hovered ? 1 : 0
        iconName: forgetButton.confirming ? "" : "window-close-symbolic"
        iconSize: StyleControl.iconSizeSm
        text: forgetButton.confirming ? "Forget" : ""
        paddingHorizontal: forgetButton.confirming
            ? StylePopover.pillPaddingH
            : StylePopover.iconButtonPadding
        paddingVertical: forgetButton.confirming
            ? StylePopover.pillPaddingV
            : StylePopover.iconButtonPadding
        interactive: hover.hovered
        onClicked: {
            if (forgetButton.confirming)
                BluetoothState.forgetDevice(row.device)
            else
                forgetButton.confirming = true
        }

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.easeDurationFast
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: row.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (!row.busy)
                BluetoothState.activateDevice(row.device)
        }
    }
}
