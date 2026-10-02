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
    // An icon rather than a picture: it sits inside the tile with air round it
    // instead of running to the edge.
    property bool isIcon: false
    readonly property int inset: isIcon ? Math.round(width / 6) : 0

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
        anchors.margins: root.inset
        visible: false
        source: root.width > 0 ? root.source : ""
        fillMode: root.isIcon ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.width * 2, root.height * 2)
    }

    Rectangle {
        id: roundedMask

        anchors.fill: parent
        anchors.margins: root.inset
        radius: Math.max(0, root.radius - root.inset)
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        anchors.margins: root.inset
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
