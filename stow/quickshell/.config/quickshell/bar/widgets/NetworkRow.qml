import QtQuick
import Quickshell
import qs
import qs.components
import qs.config
import qs.services

// One network in the Wi-Fi list: strength, name, and what joining it would mean.
// A secured network the shell has no credentials for grows a passphrase field in
// place rather than handing the reader off to a separate dialog.
Rectangle {
    id: row

    required property var network

    readonly property bool isConnected: network.path.length > 0 && network.path === WifiState.connectedPath
    readonly property bool busy: network.path.length > 0 && network.path === WifiState.busyPath
    readonly property bool expanded: network.path.length > 0 && network.path === WifiState.passphrasePath
    readonly property bool failed: network.path.length > 0 && network.path === WifiState.errorPath

    readonly property string securityText: {
        if (row.network.type === "open")
            return "Open network"
        if (row.network.type === "8021x")
            return "Enterprise"
        if (row.network.type === "wep")
            return "Secured · WEP"
        return "Secured"
    }
    readonly property string statusText: {
        if (row.busy)
            return "Connecting…"
        if (row.isConnected)
            return WifiState.connectionDetail.length > 0 ? WifiState.connectionDetail : "Connected"
        if (row.failed)
            return WifiState.errorText
        if (row.network.saved && !row.network.inRange)
            return "Saved · out of range"
        if (row.network.saved)
            return "Saved · " + row.securityText
        return row.securityText
    }

    implicitHeight: expanded ? StylePopover.listRowExpandedHeight : StylePopover.listRowHeight
    height: implicitHeight
    radius: StyleTokens.radiusSm
    // The field below sits at a fixed offset and the row's growth uncovers it.
    // Without this clip it would be drawn outside the row at full size from the
    // first frame.
    clip: true
    color: hover.hovered || row.expanded ? StyleTokens.alphaLight : StyleTokens.transparent
    // A saved network out of range is listed for context, not for joining.
    opacity: row.network.inRange ? 1 : StyleTokens.opacityDisabled

    Behavior on color {
        ColorAnimation {
            duration: StyleTokens.easeDurationFast
            easing.type: StyleTokens.easeStandard
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: StyleTokens.easeDurationFast
            easing.type: StyleTokens.easeStandard
        }
    }

    // Leaving the row drops the forget confirmation. Without this the button
    // stays confirming behind opacity 0, so the next hover would forget on one
    // click with no warning shown.
    HoverHandler {
        id: hover
    }

    SignalBars {
        id: signalMeter

        anchors.left: parent.left
        anchors.leftMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
        anchors.top: parent.top
        anchors.topMargin: (StylePopover.listRowHeight - height) / 2
        filled: row.network.strength
    }

    Column {
        id: labels

        anchors.left: signalMeter.right
        anchors.leftMargin: StyleTokens.space10
        anchors.right: rowActions.left
        anchors.rightMargin: StyleTokens.space6
        anchors.top: parent.top
        anchors.topMargin: (StylePopover.listRowHeight - height) / 2
        spacing: StyleTokens.space1

        Text {
            width: parent.width
            text: row.network.name
            color: Colors.base05
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeSm
            font.weight: row.isConnected ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: row.statusText
            color: row.failed ? Colors.base08 : Colors.base04
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeXs
            elide: Text.ElideRight
        }
    }

    RowActions {
        id: rowActions

        anchors.right: parent.right
        anchors.rightMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
        anchors.top: parent.top
        anchors.topMargin: (StylePopover.listRowHeight - height) / 2
        hovered: hover.hovered
        showDisconnect: row.isConnected
        showRemove: row.network.saved
        busy: row.busy
        onDisconnectRequested: WifiState.disconnect()
        onRemoveRequested: WifiState.forget(row.network)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        // The connected row has nothing to activate — dropping the link is the
        // trailing X's job, so a click meant to inspect this row cannot
        // disconnect it.
        cursorShape: row.network.inRange && !row.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (row.network.inRange && !row.isConnected)
                WifiState.activate(row.network)
        }
    }

    // The passphrase field. Sits above the row's MouseArea so a click lands in
    // the field instead of collapsing the row that holds it.
    //
    // Anchored to the TOP, one label-block down, so it holds still while the row
    // grows past it. Anchoring it to the bottom edge instead made it appear on
    // top of the network's own name and travel down across it — the row grew,
    // but the field it revealed was moving too.
    Rectangle {
        id: passphraseField

        z: 2
        anchors.left: parent.left
        anchors.leftMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
        anchors.right: parent.right
        anchors.rightMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
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
                duration: StyleTokens.easeDurationFast
                easing.type: StyleTokens.easeStandard
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: StyleTokens.easeDurationFast
                easing.type: StyleTokens.easeStandard
            }
        }

        function submit() {
            if (input.text.length > 0)
                WifiState.connectWithPassphrase(row.network, input.text)
            input.text = ""
        }

        onVisibleChanged: {
            if (visible)
                input.forceActiveFocus()
            else
                input.text = ""
        }

        TextInput {
            id: input

            anchors.left: parent.left
            anchors.leftMargin: StyleTokens.space8
            anchors.right: joinButton.left
            anchors.rightMargin: StyleTokens.space6
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.base05
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeSm
            echoMode: TextInput.Password
            selectByMouse: true
            selectionColor: StyleTokens.alphaLight
            selectedTextColor: Colors.base07
            clip: true

            onAccepted: passphraseField.submit()

            Keys.onEscapePressed: WifiState.passphrasePath = ""

            Text {
                anchors.fill: parent
                visible: input.text.length === 0
                text: "Password"
                color: Colors.base04
                font: input.font
                verticalAlignment: Text.AlignVCenter
            }
        }

        PillButton {
            id: joinButton

            anchors.right: parent.right
            anchors.rightMargin: StyleTokens.space2
            anchors.verticalCenter: parent.verticalCenter
            text: "Join"
            fontSize: StyleTokens.fontSizeXs
            paddingHorizontal: StylePopover.ghostPaddingH
            paddingVertical: StyleTokens.space2
            interactive: input.text.length > 0
            opacity: input.text.length > 0 ? 1 : StyleTokens.opacityDisabled
            onClicked: passphraseField.submit()
        }
    }
}
