import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.components
Row {
    id: root

    property var shellWindow

    visible: SystemTray.items.values.length > 0
    spacing: 2

    Repeater {
        model: SystemTray.items

        IconButton {
            required property var modelData

            iconSource: modelData.icon
            iconSize: 12
            interactive: true
      
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                    modelData.display(root.shellWindow, x, y);
                    return;
                }

                if (mouse.button === Qt.MiddleButton) {
                    modelData.secondaryActivate();
                    return;
                }

                if (modelData.onlyMenu && modelData.hasMenu) {
                    modelData.display(root.shellWindow, x, y);
                } else {
                    modelData.activate();
                }
            }
        }
    }
}
