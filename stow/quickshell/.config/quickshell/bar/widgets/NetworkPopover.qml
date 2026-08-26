import QtQuick
import qs
import qs.components
import qs.config
import qs.services
// `Network` unqualified would resolve to the sibling bar widget of that name,
// not the service, so the service side stays namespaced.
import qs.services as Services

PopoverPanel {
    id: root

    readonly property int popoverWidth: StylePopover.panelWidth

    // The list only polls at speed while it is on screen, and a passphrase
    // field left open would be waiting for a keyboard that is no longer here.
    onActiveChanged: {
        WifiState.detailed = active
        if (active) {
            WifiState.clearError()
            WifiState.refresh()
        } else {
            WifiState.passphrasePath = ""
        }
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
                title: "Wi-Fi"

                PillButton {
                    text: WifiState.powered ? "On" : "Off"
                    interactive: WifiState.available
                    onClicked: WifiState.togglePowered()
                }
            }

            PopoverSeparator {
                width: parent.width
            }

            // The bar icon can read as wired while this panel is about Wi-Fi.
            // Naming the cable keeps the panel honest about why the machine is
            // online even with the radio off.
            Item {
                width: parent.width
                visible: Services.Network.hasWired
                implicitHeight: StylePopover.listRowHeight
                height: implicitHeight

                ThemedIcon {
                    id: wiredIcon

                    anchors.left: parent.left
                    anchors.leftMargin: StylePopover.contentPaddingH
                    anchors.verticalCenter: parent.verticalCenter
                    source: IconRegistry.networkIcon("wired")
                }

                Column {
                    anchors.left: wiredIcon.right
                    anchors.leftMargin: StyleTokens.space10
                    anchors.right: parent.right
                    anchors.rightMargin: StylePopover.contentPaddingH
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: StyleTokens.space1

                    Text {
                        width: parent.width
                        text: "Ethernet"
                        color: Colors.base05
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeSm
                        font.weight: Services.Network.linkType === "wired" ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: Services.Network.linkType === "wired" ? "Connected · in use" : "Connected"
                        color: Colors.base04
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeXs
                        elide: Text.ElideRight
                    }
                }
            }

            PopoverSeparator {
                width: parent.width
                visible: Services.Network.hasWired
            }

            PopoverMessage {
                visible: !WifiState.powered
                width: parent.width
                height: StylePopover.emptyStateHeight
                text: WifiState.available
                    ? "Wi-Fi is off"
                    : (WifiState.loaded ? "No Wi-Fi adapter" : "Looking for a radio…")
            }

            // Scrolls as one list so the section eyebrows travel with their
            // rows; the panel keeps a fixed header above it.
            Flickable {
                id: networkList

                visible: WifiState.powered
                width: parent.width
                height: visible ? Math.min(networkColumn.implicitHeight, StylePopover.listMaxHeight) : 0
                contentWidth: width
                contentHeight: networkColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: networkColumn

                    width: networkList.width
                    topPadding: StylePopover.contentPaddingV
                    bottomPadding: StylePopover.contentPaddingV
                    spacing: StylePopover.listRowSpacing

                    PopoverSection {
                        visible: !!WifiState.connectedNetwork
                        width: parent.width
                        label: "Connected"
                    }

                    // A single-item model rather than a row with a placeholder
                    // network: nothing to render means nothing instantiated.
                    Repeater {
                        model: WifiState.connectedNetwork ? [WifiState.connectedNetwork] : []

                        NetworkRow {
                            required property var modelData

                            x: StylePopover.listRowInset
                            width: networkColumn.width - StylePopover.listRowInset * 2
                            network: modelData
                        }
                    }

                    PopoverSection {
                        visible: WifiState.savedCount > 0
                        width: parent.width
                        topGap: WifiState.connectedNetwork ? StylePopover.sectionTopGap : 0
                        label: "Saved"
                    }

                    Repeater {
                        model: WifiState.savedNetworks

                        NetworkRow {
                            required property var modelData

                            x: StylePopover.listRowInset
                            width: networkColumn.width - StylePopover.listRowInset * 2
                            network: modelData
                        }
                    }

                    // Always present while the radio is on, so scanning has a
                    // fixed home attached to the list it fills instead of a
                    // free-floating control above everything.
                    PopoverSection {
                        width: parent.width
                        topGap: WifiState.connectedNetwork || WifiState.savedCount > 0
                            ? StylePopover.sectionTopGap
                            : 0
                        label: "Available"

                        Button {
                            text: WifiState.scanning ? "Scanning…" : "Scan"
                            fontSize: StyleTokens.fontSizeXs
                            paddingHorizontal: StylePopover.ghostPaddingH
                            paddingVertical: StylePopover.ghostPaddingV
                            interactive: !WifiState.scanning
                            onClicked: WifiState.scan()
                        }
                    }

                    PopoverMessage {
                        visible: WifiState.openCount === 0
                        width: parent.width
                        height: StylePopover.listRowHeight
                        text: WifiState.scanning ? "Searching…" : "No other networks found"
                    }

                    Repeater {
                        model: WifiState.openNetworks

                        NetworkRow {
                            required property var modelData

                            x: StylePopover.listRowInset
                            width: networkColumn.width - StylePopover.listRowInset * 2
                            network: modelData
                        }
                    }
                }
            }
        }
    }
}
