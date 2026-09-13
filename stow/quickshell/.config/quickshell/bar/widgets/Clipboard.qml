import QtQuick
import qs.components
import qs.config
import qs.services

Button {
    id: root
    required property var barWindow

    iconSource: IconRegistry.themeIcon("edit-paste-symbolic")
    interactive: true
    active: popover.open
    onClicked: popover.toggle()
    Accessible.name: "Clipboard history"

    Connections {
        target: ClipboardHistory
        function onToggleRequested(screen) {
            if (screen === root.barWindow.screen)
                popover.toggle()
        }
        function onCopied() {
            if (popover.open)
                popover.dismissNow()
        }
    }

    BarPopover {
        id: popover
        barWindow: root.barWindow
        anchorItem: root
        acceptsKeyboard: true

        ClipboardPopover {
            active: popover.open
            onDismiss: popover.open = false
        }
    }
}
