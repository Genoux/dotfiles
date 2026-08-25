import QtQuick
import qs.components

Button {
    id: root

    required property var barWindow

    iconName: "bluetooth-active-symbolic"
    interactive: true
    active: popover.open
    onClicked: popover.toggle()

    BarPopover {
        id: popover

        barWindow: root.barWindow
        anchorItem: root

        BluetoothPopover {
            active: popover.open
        }
    }
}
