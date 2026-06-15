import QtQuick
import qs.config
import qs.components
import qs.services

Row {
    visible: Privacy.anyActive
    spacing: 2

    Button {
        visible: Privacy.webcam
        iconName: "camera-video-symbolic"
        background: StylePrivacy.webcamFill
        hoverBackground: StylePrivacy.webcamFill
        borderWidth: 1
        borderColor: StylePrivacy.webcamBorder
    }

    Button {
        visible: Privacy.mic
        iconName: "mic-on"
        background: StylePrivacy.micFill
        hoverBackground: StylePrivacy.micFill
        borderWidth: 1
        borderColor: StylePrivacy.micBorder
    }

    Button {
        visible: Privacy.screenrecord
        iconName: "video-display-symbolic"
        background: StylePrivacy.screenFill
        hoverBackground: StylePrivacy.screenFill
        borderWidth: 1
        borderColor: StylePrivacy.screenBorder
    }
}
