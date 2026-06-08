import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services as Services

PanelWindow {
    id: root

    required property var screen

    readonly property bool active: Services.PowerMenu.visible && Services.PowerMenu.screen === root.screen

    property bool displayed: false

    screen: root.screen
    visible: displayed
    color: Style.transparent
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "power-menu-backdrop"

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

        interval: Style.powerMenuHideDuration
        onTriggered: root.displayed = false
    }

    Rectangle {
        anchors.fill: parent
        color: Style.powerMenuBackdrop
        opacity: root.active ? Style.powerMenuBackdropOpacity : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.active ? Style.powerMenuShowDuration : Style.powerMenuHideDuration
                easing.type: root.active ? Easing.OutCubic : Easing.InCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: Services.PowerMenu.close()
    }
}
