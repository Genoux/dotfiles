import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
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
        radius: StyleTokens.radiusMd
        color: StyleOsd.background(Colors.base00)
        border.width: 1
        border.color: StyleOsd.border

        ColumnLayout {
            anchors.centerIn: parent
            spacing: StyleOsd.contentSpacing

            Button {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: StyleOsd.iconSize
                Layout.preferredHeight: StyleOsd.iconSize
                width: StyleOsd.iconSize
                height: StyleOsd.iconSize
                iconName: VolumeOsd.iconName
                iconSize: StyleOsd.iconSize
                interactive: false
                background: StyleTokens.transparent
                hoverBackground: StyleTokens.transparent
            }

            VolumeStepBar {
                Layout.alignment: Qt.AlignHCenter
                volume: VolumeOsd.volume
                muted: VolumeOsd.muted
            }
        }
    }
}
