import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config

PanelWindow {
    id: root

    required property var screen
    required property bool active
    required property string layerNamespace

    signal dismissed

    property bool displayed: false

    screen: root.screen
    visible: displayed
    color: StyleTokens.transparent
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: root.layerNamespace

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

        interval: StyleOverlay.hideDuration
        onTriggered: root.displayed = false
    }

    Rectangle {
        anchors.fill: parent
        color: StyleOverlay.backdrop
        opacity: root.active ? StyleOverlay.backdropOpacity : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.active ? StyleOverlay.showDuration : StyleOverlay.hideDuration
                easing.type: root.active ? Easing.OutCubic : Easing.InCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: root.dismissed()
    }
}
