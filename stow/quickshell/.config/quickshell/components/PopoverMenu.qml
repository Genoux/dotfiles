import QtQuick
import qs.config

PopoverPanel {
    id: menu

    property var entries: []

    signal selected(int index)

    Column {
        spacing: 2
        width: StylePopover.minWidth

        Repeater {
            model: menu.entries

            PopoverAction {
                required property var modelData
                required property int index

                width: StylePopover.minWidth
                label: modelData?.label ?? ""
                separator: modelData?.separator ?? false
                onActivated: menu.selected(index)
            }
        }
    }
}
