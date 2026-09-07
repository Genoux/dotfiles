import qs.components
import qs.config

Button {
    id: root

    required property var barWindow

    iconSource: IconRegistry.barControlIcon("info")
    interactive: true
    active: popover.open
    onClicked: popover.toggle()

    BarPopover {
        id: popover

        barWindow: root.barWindow
        anchorItem: root
        centered: true

        SystemInfoPopover {
            active: popover.open
            onCloseRequested: popover.open = false
        }
    }
}
