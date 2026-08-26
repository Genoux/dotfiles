import QtQuick
import Quickshell
import qs
import qs.config
import qs.components
import qs.services as Services

Button {
    interactive: true
    iconName: "terminal-symbolic"
    onClicked: ShellActions.openDotfilesMenu()

    Rectangle {
        visible: Services.Dotfiles.updatesAvailable
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: StyleTokens.space4
        anchors.topMargin: StyleTokens.space4
        width: 5
        height: 5
        radius: width / 2
        color: Colors.base0D
    }
}
