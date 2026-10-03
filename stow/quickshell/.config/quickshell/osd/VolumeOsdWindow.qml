import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.config
import qs.components
import qs.services

PanelWindow {
    id: root

    required property var screen

    screen: root.screen
    visible: VolumeOsd.visible
    color: StyleTokens.transparent
    exclusionMode: ExclusionMode.Ignore

    implicitWidth: StyleOsd.width
    implicitHeight: StyleOsd.height

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "osd"

    anchors.bottom: true
    margins.bottom: StyleShellLayout.osdBottomMargin

    Rectangle {
        anchors.fill: parent
        radius: StyleOsd.radius
        color: StyleOverlay.surface

        LevelBar {
            anchors.fill: parent
            anchors.margins: StyleOsd.padding
            enabled: false
            label: "Volume"
            value: VolumeOsd.volume
            muted: VolumeOsd.muted
        }
    }
}
