import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.config
import qs.services

PopoverPanel {
    id: root

    readonly property int popoverWidth: StylePopover.systemInfoWidth
    readonly property string operatingSystem: SystemInfo.software.find(row => row.label === "OS")?.value ?? ""
    readonly property string machineModel: SystemInfo.hardware.find(row => row.label === "PC")?.value ?? ""

    signal closeRequested()

    FontMetrics {
        id: artMetrics
        font.family: StyleTokens.fontMono
        font.pixelSize: StylePopover.systemInfoArtSize
    }

    // ColumnLayout reports an implicit size that ignores its own anchor margins,
    // so the panel would size to the content and drop the inset. This carries it.
    Item {
        implicitWidth: root.popoverWidth
        implicitHeight: content.implicitHeight + StylePopover.contentPaddingH * 2
        width: implicitWidth
        height: implicitHeight

        ColumnLayout {
            id: content

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: StylePopover.contentPaddingH
            spacing: StyleTokens.space12

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "About this system"
                    color: Colors.base04
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeSm
                }

                PillButton {
                    text: "Close"
                    onClicked: root.closeRequested()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: StyleTokens.space4
                Layout.bottomMargin: StyleTokens.space8
                spacing: StyleTokens.space6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: StyleTokens.space12
                    Layout.preferredWidth: artMetrics.averageCharacterWidth * SystemInfo.gridWidth
                    Layout.preferredHeight: artMetrics.height * SystemInfo.gridHeight
                    text: SystemInfo.art
                    textFormat: Text.StyledText
                    font: artMetrics.font
                    lineHeight: 1
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: SystemInfo.hostname || "Reading system…"
                    color: Colors.base05
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeXl
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: [root.machineModel, root.operatingSystem].filter(Boolean).join(" · ")
                    color: Colors.base04
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeSm
                    wrapMode: Text.Wrap
                }
            }

            Text {
                Layout.fillWidth: true
                visible: SystemInfo.error.length > 0
                text: SystemInfo.error
                color: Colors.base08
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
                wrapMode: Text.Wrap
            }

            Repeater {
                model: [
                    { title: "HARDWARE", rows: SystemInfo.hardware.filter(row => row.label !== "PC") },
                    { title: "SOFTWARE", rows: SystemInfo.software.filter(row => row.label !== "OS") }
                ]

                Rectangle {
                    id: group

                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: groupContent.implicitHeight + StylePopover.systemInfoGroupPadding * 2
                    radius: StyleTokens.radiusSm
                    color: StyleTokens.alphaLight
                    border.width: StyleTokens.borderWidth
                    border.color: StyleTokens.alphaHairline

                    ColumnLayout {
                        id: groupContent

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: StylePopover.systemInfoGroupPadding
                        spacing: 0

                        Text {
                            Layout.bottomMargin: StyleTokens.space8
                            text: group.modelData.title
                            color: Colors.base04
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeXs
                            font.weight: Font.DemiBold
                            font.letterSpacing: StyleTokens.space1
                        }

                        Repeater {
                            model: group.modelData.rows

                            ColumnLayout {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: 0

                                PopoverSeparator {
                                    Layout.fillWidth: true
                                    visible: index > 0
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: StylePopover.systemInfoRowPadding
                                    Layout.bottomMargin: StylePopover.systemInfoRowPadding
                                    spacing: StylePopover.systemInfoLabelGap

                                    Text {
                                        Layout.preferredWidth: StylePopover.systemInfoLabelWidth
                                        Layout.alignment: Qt.AlignTop
                                        text: modelData.label
                                        color: Colors.base04
                                        font.family: StyleTokens.fontSans
                                        font.pixelSize: StyleTokens.fontSizeSm
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.value
                                        color: Colors.base05
                                        font.family: StyleTokens.fontSans
                                        font.pixelSize: StyleTokens.fontSizeSm
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: StyleTokens.space4
                text: SystemInfo.uptime ? "Uptime  ·  " + SystemInfo.uptime : ""
                color: Colors.base04
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }
}
