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
    readonly property var entries: Services.PowerMenu.entries.filter(entry => !entry.toggleLayout)
    readonly property int tileWidth: (width - StyleIsland.fillInset * 2) / entries.length

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

        Item {
            width: parent.width
            height: StylePopover.tileHeight + StyleIsland.fillPaddingTop + StyleIsland.pagePaddingBottom

            SlidingHighlight {
                run: tileRow
            }

            Row {
                id: tileRow

                anchors.top: parent.top
                anchors.topMargin: StyleIsland.fillPaddingTop
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                Repeater {
                    model: root.entries

                    PopoverTile {
                        required property var modelData

                        width: root.tileWidth
                        label: modelData.label
                        iconSource: IconRegistry.source(modelData.iconName)
                        onActivated: {
                            root.actionChosen();
                            Services.PowerMenu.activate(modelData);
                        }
                    }
                }
            }
        }
    }
}
