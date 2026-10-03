import QtQuick
import qs
import qs.components
import qs.config
import qs.services as Services

Item {
    id: root

    property bool active: false

    signal actionChosen()

    // The island/bar switch lives on the More page; here are only the session's.
    readonly property var entries: Services.PowerMenu.entries

    implicitWidth: StyleIsland.pageWidth
    implicitHeight: content.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Column {
        id: content

        width: parent.width
        spacing: 0

        PopoverHeader {
            width: parent.width
            title: "Power"
        }

        PopoverSeparator {
            width: parent.width
        }

        // A list rather than a row of tiles: five captions do not fit five
        // tiles across the island without crowding.
        Item {
            width: parent.width
            height: actionColumn.height + StyleIsland.fillPaddingTop + StyleIsland.pagePaddingBottom

            SlidingHighlight {
                run: actionColumn
            }

            Column {
                id: actionColumn

                x: StyleIsland.fillInset
                y: StyleIsland.fillPaddingTop
                width: parent.width - StyleIsland.fillInset * 2
                spacing: StylePopover.listRowSpacing

                Repeater {
                    model: root.entries

                    Item {
                        id: actionRow

                        required property var modelData

                        readonly property bool hovered: actionArea.containsMouse

                        width: parent.width
                        height: StylePopover.listRowHeight

                        Rectangle {
                            id: glyphWell

                            x: StylePopover.contentPaddingH - StyleIsland.fillInset
                            anchors.verticalCenter: parent.verticalCenter
                            width: StylePopover.rowGlyphWellSize
                            height: width
                            radius: StyleControl.chipRadius
                            color: StyleTokens.alphaLight

                            ThemedIcon {
                                anchors.centerIn: parent
                                source: IconRegistry.source(actionRow.modelData.iconName)
                            }
                        }

                        Text {
                            anchors.left: glyphWell.right
                            anchors.leftMargin: StyleTokens.space10
                            anchors.verticalCenter: parent.verticalCenter
                            text: actionRow.modelData.label
                            color: Colors.base05
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeSm
                        }

                        MouseArea {
                            id: actionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.actionChosen();
                                Services.PowerMenu.activate(actionRow.modelData);
                            }
                        }
                    }
                }
            }
        }
    }
}
