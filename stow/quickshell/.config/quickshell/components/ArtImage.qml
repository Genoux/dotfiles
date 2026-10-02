import Qt5Compat.GraphicalEffects
import QtQuick
import qs
import qs.config

// Cover art on a rounded tile. The placeholder is always underneath, so art
// that is slow to arrive, or never does, fades over a finished tile rather than
// a hole.
Item {
    id: root

    property string source: ""
    property int radius: StyleTokens.radiusSm

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: StyleTokens.alphaLight
        border.width: StyleTokens.borderWidth
        border.color: StyleOverlay.borderSubtle

        ThemedIcon {
            anchors.centerIn: parent
            visible: root.width >= StyleControl.iconSize * 2
            size: Math.round(root.width / 4)
            source: IconRegistry.themeIcon("audio-x-generic-symbolic")
            tint: Colors.base04
        }
    }

    Image {
        id: art

        anchors.fill: parent
        visible: false
        source: root.width > 0 ? root.source : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.width * 2, root.height * 2)
    }

    Rectangle {
        id: roundedMask

        anchors.fill: parent
        radius: root.radius
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        source: art
        maskSource: roundedMask
        opacity: art.status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.motionEnterDuration
                easing.type: StyleTokens.easeFade
            }
        }
    }
}
