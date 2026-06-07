import QtQuick
import qs.config
import qs.components
import qs.services

Row {
    id: root

    visible: Privacy.anyActive
    spacing: 2

    PrivacyButton {
        visible: Privacy.webcam
        iconName: "camera-video-symbolic"
        fillColor: Style.privacyWebcamFill
        borderColor: Style.privacyWebcamBorder
    }

    PrivacyButton {
        visible: Privacy.mic
        iconName: "mic-on"
        fillColor: Style.privacyMicFill
        borderColor: Style.privacyMicBorder
    }

    PrivacyButton {
        visible: Privacy.screenrecord
        iconName: "video-display-symbolic"
        fillColor: Style.privacyScreenFill
        borderColor: Style.privacyScreenBorder
    }
}
