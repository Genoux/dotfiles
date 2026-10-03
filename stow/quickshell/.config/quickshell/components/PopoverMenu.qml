import QtQuick
import qs.components
import qs.config

PopoverPanel {
    id: menu

    property var entries: []
    // Compact bar of icon tiles with captions underneath, instead of a
    // full-width text list. Record picker uses this; tray stays a list.
    property bool iconRow: false

    signal selected(int index)

    fitContent: iconRow

    // One inset on all four sides: a tile is square-ish chrome, so unlike a
    // full-width list row it reads as off-centre the moment x and y disagree.
    SlidingHighlight {
        run: iconTileRow
    }

    Row {
        id: iconTileRow

        visible: menu.iconRow
        spacing: StyleIsland.tileGridGap
        padding: StylePopover.contentPaddingV

        Repeater {
            model: menu.iconRow ? menu.entries : []

            PopoverTile {
                required property var modelData
                required property int index

                width: StylePopover.tileWidth
                label: modelData?.label ?? ""
                iconSource: IconRegistry.source(modelData?.iconName ?? "")
                onActivated: menu.selected(index)
            }
        }
    }

    SlidingHighlight {
        run: listColumn
    }

    Column {
        id: listColumn

        visible: !menu.iconRow
        spacing: StylePopover.listRowSpacing
        width: visible ? StylePopover.panelWidth : 0
        height: visible ? implicitHeight : 0

        Repeater {
            model: menu.iconRow ? [] : menu.entries

            PopoverAction {
                required property var modelData
                required property int index

                width: StylePopover.panelWidth
                label: modelData?.label ?? ""
                separator: modelData?.separator ?? false
                onActivated: menu.selected(index)
            }
        }
    }
}
