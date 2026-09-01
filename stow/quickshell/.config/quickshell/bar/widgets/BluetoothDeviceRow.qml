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
        || BluetoothState.busyAddress === device.address
    readonly property string displayName: {
        const named = String(device.name || device.deviceName || "").trim()
        return named.length > 0 ? named : device.address
    }
    readonly property string statusText: {
        if (device.pairing)
            return "Pairing…"
        if (BluetoothState.busyAddress === device.address)
            return device.paired ? "Connecting…" : "Pairing…"
        if (device.state === Bluez.BluetoothDeviceState.Connecting)
            return "Connecting…"
        if (device.state === Bluez.BluetoothDeviceState.Disconnecting)
            return "Disconnecting…"
        if (device.blocked)
            return "Blocked"
        if (BluetoothState.errorAddress === device.address)
            return BluetoothState.errorText
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
    opacity: device.blocked ? StyleTokens.opacityDisabled : 1

    Behavior on color {
        ColorAnimation {
            duration: StyleTokens.easeDurationFast
            easing.type: StyleTokens.easeStandard
        }
    }

    HoverHandler {
        id: hover
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
        anchors.leftMargin: StyleTokens.space10
        anchors.right: rowActions.left
        anchors.rightMargin: StyleTokens.space6
        anchors.verticalCenter: parent.verticalCenter
        spacing: StyleTokens.space1

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

    RowActions {
        id: rowActions

        anchors.right: parent.right
        anchors.rightMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
        anchors.verticalCenter: parent.verticalCenter
        hovered: hover.hovered
        showDisconnect: row.device.connected
        showRemove: row.device.paired
        busy: row.busy
        onDisconnectRequested: BluetoothState.disconnectDevice(row.device)
        onRemoveRequested: BluetoothState.forgetDevice(row.device)
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: !row.busy && !row.device.connected
        gesturePolicy: TapHandler.ReleaseWithinBounds
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onTapped: BluetoothState.activateDevice(row.device)
    }
}
