import QtQuick
import qs.components
import qs.config

Button {
    id: root

    required property var barWindow

    iconSource: IconRegistry.bluetoothIcon(true)
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
