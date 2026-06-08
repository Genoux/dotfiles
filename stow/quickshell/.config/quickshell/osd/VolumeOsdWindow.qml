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
    color: Style.transparent
    exclusionMode: ExclusionMode.Ignore

    implicitWidth: Style.osdWidth
    implicitHeight: Style.osdHeight

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "osd"

    anchors.bottom: true
    margins.bottom: Style.osdBottomMargin

    Rectangle {
        anchors.fill: parent
        radius: Style.radiusMd
        color: Style.osdBackground(Colors.base00)
        border.width: 1
        border.color: Style.osdBorder

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Style.osdContentSpacing

            IconButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Style.osdIconSize
                Layout.preferredHeight: Style.osdIconSize
                width: Style.osdIconSize
                height: Style.osdIconSize
                iconName: VolumeOsd.iconName
                iconSize: Style.osdIconSize
                interactive: false
                background: Style.transparent
                hoverBackground: Style.transparent
            }

            VolumeStepBar {
                Layout.alignment: Qt.AlignHCenter
                volume: VolumeOsd.volume
                muted: VolumeOsd.muted
            }
        }
    }
}
