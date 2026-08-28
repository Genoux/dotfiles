import QtQuick
import qs.components
import qs.config
import qs.services as Services

Button {
    id: root

    required property var barWindow

    interactive: true
    iconSource: IconRegistry.barControlIcon("power")
    active: popover.open
    onClicked: popover.toggle()

    BarPopover {
        id: popover

        barWindow: root.barWindow
        anchorItem: root

        PopoverMenu {
            active: popover.open
            iconRow: true
            entries: Services.PowerMenu.entries
            onSelected: (index) => {
                popover.dismissNow();
                Services.PowerMenu.activate(Services.PowerMenu.entries[index]);
            }
        }
    }

    // Super+Escape reaches the shell over IPC, which has no anchor of its own —
    // it targets the bar on the focused screen instead.
    Connections {
        target: Services.PowerMenu

        function onToggleRequested(targetScreen) {
            if (targetScreen === root.barWindow?.screen)
                popover.toggle();
        }
    }
}
