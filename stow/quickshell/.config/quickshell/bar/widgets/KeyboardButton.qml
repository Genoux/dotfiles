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
    minimumWidth: Style.pillWidth
    implicitWidth: Style.pillWidth
    Layout.minimumWidth: Style.pillWidth
    Layout.preferredWidth: Style.pillWidth
    Layout.maximumWidth: Style.pillWidth
    interactive: true
    onClicked: Keyboard.switchLayout()
}
