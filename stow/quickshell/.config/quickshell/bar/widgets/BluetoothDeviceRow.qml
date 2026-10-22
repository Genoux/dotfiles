import QtQuick
import Quickshell
import Quickshell.Bluetooth as Bluez
import qs
import qs.components
import qs.config
import qs.services

// A pairing in progress is answered on the device's own row — its status line
// carries the prompt, and a PIN or passkey grows a field in place — so the
// reader never has to match a detached banner back to the row it is about.
Rectangle {
    id: row

    required property var device

    readonly property bool busy: device.pairing
        || device.state === Bluez.BluetoothDeviceState.Connecting
        || device.state === Bluez.BluetoothDeviceState.Disconnecting
        || BluetoothState.busyAddress === device.address
    readonly property bool pairingHere: BluetoothState.pairingAddress.length > 0
        && BluetoothState.pairingAddress === device.address
    readonly property var prompt: pairingHere ? BluetoothState.pairingPrompt : ({})
    readonly property bool expanded: pairingHere && BluetoothState.pairingNeedsInput
    readonly property string displayName: {
        const named = String(device.name || device.deviceName || "").trim()
        return named.length > 0 ? named : device.address
    }
    readonly property string statusText: {
        if (row.prompt.kind === "confirm")
            return `Confirm ${row.prompt.code} matches`
        if (row.prompt.kind === "display")
            return `Type ${row.prompt.code}, then Enter`
        if (row.prompt.kind === "authorize")
            return "Allow pairing?"
        if (row.prompt.kind === "pin")
            return "Enter the PIN"
        if (row.prompt.kind === "passkey")
            return "Enter the passkey"
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

        // Symbolic first: full-colour theme art ignores the tint and vanishes on the
        // connected row's light chip.
        const themed = Quickshell.iconPath(`${name}-symbolic`, true) || Quickshell.iconPath(name, true)
        return String(themed).length > 0 ? themed : IconRegistry.bluetoothIcon(true)
    }

    implicitHeight: expanded ? StylePopover.listRowExpandedHeight : StylePopover.listRowHeight
    height: implicitHeight
    radius: StylePopover.listRowRadius
    // The field below sits at a fixed offset and the row's growth uncovers it.
    clip: true
    // A pairing outlasts the pointer, so it is state rather than hover and the
    // run's indicator cannot express it.
    color: row.pairingHere ? StyleTokens.alphaLight : StyleTokens.transparent

    // The list's travelling indicator paints the hover fill for the whole run.
    readonly property bool hovered: hover.hovered
    opacity: device.blocked ? StyleTokens.opacityDisabled : 1

    Behavior on color {
        ColorAnimation {
            duration: StyleTokens.motionFeedbackDuration
            easing.type: StyleTokens.easeFade
        }
    }

    HoverHandler {
        id: hover
    }

    Rectangle {
        id: glyphWell

        anchors.left: parent.left
        anchors.leftMargin: StylePopover.contentPaddingH - row.x
        anchors.top: parent.top
        anchors.topMargin: (StylePopover.listRowHeight - height) / 2
        width: StylePopover.rowGlyphWellSize
        height: width
        radius: StyleControl.chipRadius
        color: row.device.connected ? StyleControl.chipFill : StyleTokens.alphaLight

        Behavior on color {
            ColorAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeFade
            }
        }

        ThemedIcon {
            anchors.centerIn: parent
            source: row.deviceIconSource
            tint: row.device.connected ? StyleControl.chipContent : Colors.base05
        }
    }

    Column {
        anchors.left: glyphWell.right
        anchors.leftMargin: StyleTokens.space10
        anchors.right: trailing.left
        anchors.rightMargin: StyleTokens.space6
        anchors.top: parent.top
        anchors.topMargin: (StylePopover.listRowHeight - height) / 2
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

    Row {
        id: trailing

        anchors.right: parent.right
        anchors.rightMargin: StylePopover.contentPaddingH - row.x
        anchors.top: parent.top
        anchors.topMargin: (StylePopover.listRowHeight - height) / 2
        spacing: StyleTokens.space2

        RowActions {
            anchors.verticalCenter: parent.verticalCenter
            hovered: hover.hovered
            showDisconnect: row.device.connected
            showRemove: row.device.paired
            busy: row.busy
            onDisconnectRequested: BluetoothState.disconnectDevice(row.device)
            onRemoveRequested: BluetoothState.forgetDevice(row.device)
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.pairingHere
            text: "Cancel"
            fontSize: StyleTokens.fontSizeXs
            paddingHorizontal: StylePopover.ghostPaddingH
            paddingVertical: StylePopover.ghostPaddingV
            interactive: true
            onClicked: BluetoothState.cancelPairing()
        }

        PillButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.prompt.kind === "confirm" || row.prompt.kind === "authorize"
            text: "Pair"
            active: true
            fontSize: StyleTokens.fontSizeXs
            paddingHorizontal: StylePopover.ghostPaddingH
            paddingVertical: StyleTokens.space2
            onClicked: BluetoothState.answerPairing(true)
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: !row.busy && !row.device.connected
        gesturePolicy: TapHandler.ReleaseWithinBounds
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onTapped: BluetoothState.activateDevice(row.device)
    }

    // Anchored to the top, one label-block down, so it holds still while the
    // row grows past it instead of travelling across the device's name.
    Rectangle {
        id: codeField

        z: 2
        anchors.left: parent.left
        anchors.leftMargin: StylePopover.contentPaddingH - row.x
        anchors.right: parent.right
        anchors.rightMargin: StylePopover.contentPaddingH - row.x
        anchors.top: parent.top
        anchors.topMargin: StylePopover.listRowHeight
        height: StylePopover.fieldHeight
        opacity: row.expanded ? 1 : 0
        // Kept alive while it fades out, so the text does not vanish a frame
        // before the field holding it does.
        visible: opacity > 0
        radius: StyleTokens.radiusSm
        color: StyleTokens.alphaHairline
        border.width: StyleTokens.borderWidth
        border.color: input.activeFocus ? StyleTokens.alphaLight : StyleOverlay.borderSubtle

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeFade
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeFade
            }
        }

        function submit() {
            if (input.valid)
                BluetoothState.answerPairing(true, input.text)
        }

        onVisibleChanged: {
            input.text = ""
            if (visible)
                input.forceActiveFocus()
        }

        TextInput {
            id: input

            readonly property bool valid: row.prompt.kind === "pin"
                ? text.length > 0
                : /^[0-9]{1,6}$/.test(text)

            anchors.left: parent.left
            anchors.leftMargin: StyleTokens.space8
            anchors.right: submitButton.left
            anchors.rightMargin: StyleTokens.space6
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.base05
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeSm
            maximumLength: row.prompt.kind === "pin" ? 16 : 6
            selectByMouse: true
            selectionColor: StyleTokens.alphaLight
            selectedTextColor: Colors.base07
            clip: true

            onAccepted: codeField.submit()

            Keys.onEscapePressed: BluetoothState.cancelPairing()

            Text {
                anchors.fill: parent
                visible: input.text.length === 0
                text: row.prompt.kind === "pin" ? "PIN" : "Passkey"
                color: Colors.base04
                font: input.font
                verticalAlignment: Text.AlignVCenter
            }
        }

        PillButton {
            id: submitButton

            anchors.right: parent.right
            anchors.rightMargin: StyleTokens.space2
            anchors.verticalCenter: parent.verticalCenter
            text: "Pair"
            active: true
            fontSize: StyleTokens.fontSizeXs
            paddingHorizontal: StylePopover.ghostPaddingH
            paddingVertical: StyleTokens.space2
            interactive: input.valid
            opacity: input.valid ? 1 : StyleTokens.opacityDisabled
            onClicked: codeField.submit()
        }
    }
}
