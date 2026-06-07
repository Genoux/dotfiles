import QtQuick
import Quickshell
import qs
import qs.config
import qs.components
import qs.services

IconButton {
    id: root

    interactive: true
    iconName: "input-keyboard"
    onClicked: Quickshell.execDetached(["launch-dotfiles-menu"])

    Rectangle {
        visible: Dotfiles.updatesAvailable
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 4
        anchors.topMargin: 4
        width: 5
        height: 5
        radius: 999
        color: Colors.base0D
    }
}
