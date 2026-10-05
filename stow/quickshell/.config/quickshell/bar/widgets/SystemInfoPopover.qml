import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.config
import qs.services

PopoverPanel {
    id: root

    flushBottom: true

    property int popoverWidth: StylePopover.systemInfoWidth
    // The rows carry no fill, so they take the hero's text edge directly: one
    // left edge from the hostname down to the last value.
    readonly property int textInset: fillInset + StyleIsland.heroPadding
    readonly property string operatingSystem: SystemInfo.software.find(row => row.label === "OS")?.value ?? ""
    readonly property string machineModel: SystemInfo.hardware.find(row => row.label === "PC")?.value ?? ""
    // Two runs of rows, told apart by the gap between them rather than by a
    // pair of headings. The hero already names the PC and the OS.
    readonly property var groups: [
        SystemInfo.hardware.filter(row => row.label !== "PC"),
        SystemInfo.software.filter(row => row.label !== "OS")
            .concat(SystemInfo.uptime ? [{ label: "Uptime", value: SystemInfo.uptime }] : [])
    ]

    Item {
        implicitWidth: root.popoverWidth
        // The last value ends as far from the bottom as the values sit from the
        // side; in the island the dock's own gap supplies part of it.
        implicitHeight: content.implicitHeight + root.textInset
            - StylePopover.systemInfoRowPadding - (root.embedded ? StyleIsland.dockGap : 0)
        width: implicitWidth
        height: implicitHeight

        ColumnLayout {
            id: content

            width: parent.width
            spacing: 0

            WallpaperCard {
                shown: root.displaying
                Layout.fillWidth: true
                Layout.margins: root.fillInset
                Layout.bottomMargin: 0
                Layout.preferredHeight: StylePopover.systemInfoHeroHeight

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: StyleIsland.heroPadding
                    spacing: StyleTokens.space2

                    Text {
                        width: parent.width
                        text: SystemInfo.hostname || "Reading system…"
                        color: Colors.base07
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeXl
                        font.weight: Font.Light
                        font.letterSpacing: StyleIsland.clockLetterSpacing
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: [root.machineModel, root.operatingSystem].filter(Boolean).join(" · ")
                        color: Colors.base07
                        opacity: StyleIsland.heroDateOpacity
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeSm
                        elide: Text.ElideRight
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: StylePopover.systemInfoListGap
                Layout.leftMargin: root.textInset
                Layout.rightMargin: root.textInset
                visible: SystemInfo.error.length > 0
                text: SystemInfo.error
                color: Colors.base08
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
                wrapMode: Text.Wrap
            }

            Repeater {
                model: root.groups

                ColumnLayout {
                    id: group

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    visible: modelData.length > 0
                    Layout.topMargin: index === 0 ? StylePopover.systemInfoListGap : StylePopover.systemInfoGroupGap
                    Layout.leftMargin: root.textInset
                    Layout.rightMargin: root.textInset
                    spacing: 0

                    Repeater {
                        model: group.modelData

                        RowLayout {
                            id: row

                            required property var modelData
                            required property int index
                            // A second GPU reads as a continuation of the first,
                            // not as a second "Graphics" heading.
                            readonly property bool continues: index > 0
                                && group.modelData[index - 1].label === modelData.label

                            Layout.fillWidth: true
                            Layout.topMargin: StylePopover.systemInfoRowPadding
                            Layout.bottomMargin: StylePopover.systemInfoRowPadding
                            spacing: StylePopover.systemInfoLabelGap

                            Text {
                                Layout.preferredWidth: StylePopover.systemInfoLabelWidth
                                Layout.alignment: Qt.AlignTop
                                text: row.continues ? "" : row.modelData.label
                                color: Colors.base04
                                font.family: StyleTokens.fontSans
                                font.pixelSize: StyleTokens.fontSizeSm
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.value
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
}
