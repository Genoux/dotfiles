import qs
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Pill {
    text: Keyboard.layout
    foreground: Colors.base05
    fontFamily: Style.fontSans
    fontSize: Style.fontSizeSm
    horizontalPadding: 0
    implicitWidth: Style.pillWidth
    Layout.fillWidth: false
    interactive: true
    onClicked: Keyboard.switchLayout()
}
