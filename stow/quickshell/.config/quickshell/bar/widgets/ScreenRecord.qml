import Quickshell
import QtQuick
import qs.config
import qs.components
import qs.services

IconButton {
    id: root

    property color recordingColor: Style.recording

    iconName: Privacy.screenrecord ? "media-playback-stop-symbolic" : "media-record-symbolic"
    iconSize: Style.iconSizeMd
    background: Privacy.screenrecord ? recordingColor : Style.transparent
    hoverBackground: Privacy.screenrecord ? Style.recordingHover : Style.alphaLight
    interactive: true
    onClicked: ShellActions.run(Privacy.screenrecord ? ["system-screenrecord"] : ["system-screenrecord", "region"])

    SequentialAnimation {
        running: Privacy.screenrecord
        loops: Animation.Infinite

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: Style.recordingPulse
            duration: Style.recordingPulseDuration
            easing.type: Easing.InOutQuad
        }

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: Style.recording
            duration: Style.recordingPulseDuration
            easing.type: Easing.InOutQuad
        }
    }
}
