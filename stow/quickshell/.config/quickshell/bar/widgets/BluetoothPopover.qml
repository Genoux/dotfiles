import QtQuick
import qs.components
import qs.config
import qs.services

PopoverPanel {
    id: root

    readonly property int popoverWidth: StylePopover.panelWidth

    onActiveChanged: {
        if (!active)
            BluetoothState.stopScan()
    }

    Item {
        implicitWidth: root.popoverWidth
        implicitHeight: content.implicitHeight
        width: implicitWidth
        height: implicitHeight

        Column {
            id: content

            width: parent.width
            spacing: 0

            PopoverHeader {
                width: parent.width
                title: "Bluetooth"

                Toggle {
                    checked: BluetoothState.enabled
                    interactive: BluetoothState.available && !BluetoothState.blocked
                    onToggled: BluetoothState.toggleAdapter()
                }
            }

            PopoverSeparator {
                width: parent.width
            }

            PopoverMessage {
                visible: !BluetoothState.enabled
                width: parent.width
                height: StylePopover.emptyStateHeight
                text: BluetoothState.blocked
                    ? "Bluetooth is blocked"
                    : (BluetoothState.available ? "Bluetooth is off" : "No Bluetooth adapter")
            }

            // Scrolls as one list so the section eyebrows travel with their
            // rows; the panel keeps a fixed header above it.
            Flickable {
                id: deviceList

                visible: BluetoothState.enabled
                width: parent.width
                height: visible ? Math.min(deviceColumn.implicitHeight, StylePopover.listMaxHeight) : 0
                contentWidth: width
                contentHeight: deviceColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: deviceColumn

                    width: deviceList.width
                    topPadding: StylePopover.contentPaddingV
                    bottomPadding: StylePopover.contentPaddingV
                    spacing: StylePopover.listRowSpacing

                    PopoverSection {
                        visible: BluetoothState.connectedCount > 0
                        width: parent.width
                        label: "Connected"
                    }

                    Repeater {
                        model: BluetoothState.adapter ? BluetoothState.adapter.devices : 0

                        BluetoothDeviceRow {
                            required property var modelData

                            x: StylePopover.listRowInset
                            width: deviceColumn.width - StylePopover.listRowInset * 2
                            device: modelData
                            visible: modelData.connected && !modelData.blocked
                        }
                    }

                    PopoverSection {
                        visible: BluetoothState.pairedIdleCount > 0
                        width: parent.width
                        topGap: BluetoothState.connectedCount > 0 ? StylePopover.sectionTopGap : 0
                        label: "Paired"
                    }

                    Repeater {
                        model: BluetoothState.adapter ? BluetoothState.adapter.devices : 0

                        BluetoothDeviceRow {
                            required property var modelData

                            x: StylePopover.listRowInset
                            width: deviceColumn.width - StylePopover.listRowInset * 2
                            device: modelData
                            visible: modelData.paired && !modelData.connected && !modelData.blocked
                        }
                    }

                    // Always present while the adapter is on, so scanning has a
                    // fixed home attached to the list it fills instead of a
                    // free-floating row above everything.
                    PopoverSection {
                        width: parent.width
                        topGap: BluetoothState.connectedCount > 0 || BluetoothState.pairedIdleCount > 0
                            ? StylePopover.sectionTopGap
                            : 0
                        label: "Nearby"

                        Button {
                            text: BluetoothState.discovering ? "Stop" : "Scan"
                            fontSize: StyleTokens.fontSizeXs
                            paddingHorizontal: StylePopover.ghostPaddingH
                            paddingVertical: StylePopover.ghostPaddingV
                            interactive: true
                            onClicked: BluetoothState.toggleScan()
                        }
                    }

                    PopoverMessage {
                        visible: BluetoothState.nearbyCount === 0
                        width: parent.width
                        height: StylePopover.listRowHeight
                        text: BluetoothState.discovering ? "Searching…" : "No devices found"
                    }

                    Repeater {
                        model: BluetoothState.adapter ? BluetoothState.adapter.devices : 0

                        BluetoothDeviceRow {
                            required property var modelData

                            x: StylePopover.listRowInset
                            width: deviceColumn.width - StylePopover.listRowInset * 2
                            device: modelData
                            visible: !modelData.paired && !modelData.connected && !modelData.blocked
                        }
                    }
                }
            }
        }
    }
}
