import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services as Services

PanelWindow {
    id: root

    required property var screen

    readonly property bool active: Services.Launcher.visible && Services.Launcher.screen === root.screen

    property bool displayed: false

    screen: root.screen
    visible: displayed
    color: Style.transparent
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "launcher-backdrop"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onActiveChanged: {
        if (active) {
            hideTimer.stop()
            displayed = true
        } else {
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer

        interval: Style.launcherHideDuration
        onTriggered: root.displayed = false
    }

    Rectangle {
        anchors.fill: parent
        color: Style.launcherBackdrop
        opacity: root.active ? Style.launcherBackdropOpacity : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.active ? Style.launcherShowDuration : Style.launcherHideDuration
                easing.type: root.active ? Easing.OutQuad : Easing.InQuad
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: Services.Launcher.close()
    }
}
