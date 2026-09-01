import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.config
import qs.services as Services

// A delayed capture starts only after slurp has closed. Keep the feedback on
// that monitor and out of the pointer's way, alongside the existing OSD.
PanelWindow {
    id: root

    required property var screen

    readonly property bool active: Services.CaptureState.countdownVisible
        && Services.CaptureState.countdownScreen === root.screen

    screen: root.screen
    visible: active
    color: StyleTokens.transparent
    exclusionMode: ExclusionMode.Ignore

    implicitWidth: StyleCapture.countdownSize
    implicitHeight: StyleCapture.countdownSize

    WlrLayershell.layer: WlrLayer.Overlay
    // Shared with VolumeOsdWindow so Hyprland's `osd` layer rule supplies the
    // same compositor blur; the translucent QML fill alone is not frosted glass.
    WlrLayershell.namespace: "osd"

    anchors.bottom: true
    margins.bottom: StyleShellLayout.osdBottomMargin

    Rectangle {
        anchors.fill: parent
        radius: StyleTokens.radiusMd
        color: StyleOsd.background(Colors.base00)
        border.width: StyleTokens.borderWidth
        border.color: StyleOsd.border

        Text {
            anchors.centerIn: parent
            text: Services.CaptureState.countdownSeconds
            color: Colors.base05
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeXl
            font.weight: Font.DemiBold
        }
    }
}
