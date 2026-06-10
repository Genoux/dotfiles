import Quickshell
import QtQuick
import qs.config
import qs.components
import qs.services

IconButton {
    id: root

    animateColor: false
    property color recordingColor: Style.transparent

    iconName: "media-record-symbolic"
    iconSize: Style.iconSizeMd
    background: recordingColor
    hoverBackground: Privacy.screenrecord ? Style.recordingHover : Style.alphaLight
    interactive: true
    onClicked: ShellActions.run(Privacy.screenrecord ? ["system-screenrecord"] : ["system-screenrecord", "region"])

    Component.onCompleted: {
        if (Privacy.screenrecord)
            introAnimation.start()
    }

    Connections {
        target: Privacy
        function onScreenrecordChanged() {
            introAnimation.stop()
            pulseAnimation.stop()
            fadeOutAnimation.stop()

            if (Privacy.screenrecord)
                introAnimation.start()
            else
                fadeOutAnimation.start()
        }
    }

    SequentialAnimation {
        id: introAnimation

        ColorAnimation {
            target: root
            property: "recordingColor"
            from: Style.transparent
            to: Style.recording
            duration: Style.easeDurationNormal
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: pulseAnimation.start()
        }
    }

    SequentialAnimation {
        id: pulseAnimation
        loops: Animation.Infinite

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: Style.recordingPulse
            duration: Style.recordingPulseDuration
            easing.type: Easing.InOutSine
        }

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: Style.recording
            duration: Style.recordingPulseDuration
            easing.type: Easing.InOutSine
        }
    }

    ColorAnimation {
        id: fadeOutAnimation

        target: root
        property: "recordingColor"
        to: Style.transparent
        duration: Style.easeDurationNormal
        easing.type: Easing.InCubic
    }
}
