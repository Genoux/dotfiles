import Qt5Compat.GraphicalEffects
import QtQuick
import qs.config

Item {
    id: panel

    property bool active: false
    property bool fitContent: false
    default property alias content: contentLayer.data
    readonly property int chromePadding: StylePopover.padding

    implicitWidth: (fitContent ? contentLayer.childrenRect.width : Math.max(StylePopover.minWidth, contentLayer.childrenRect.width)) + chromePadding * 2
    implicitHeight: contentLayer.childrenRect.height + chromePadding * 2
    width: implicitWidth
    height: implicitHeight
    opacity: active ? 1 : 0
    scale: active ? 1 : StylePopover.hiddenScale
    transformOrigin: Item.Bottom

    DropShadow {
        anchors.fill: surface
        source: surface
        horizontalOffset: 4
        verticalOffset: 4
        radius: 8
        samples: 17
        color: StyleOverlay.shadow
        opacity: panel.opacity
        transparentBorder: true
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: StyleTokens.radiusMd
        color: StyleOverlay.surface
        border.width: 1
        border.color: StyleOverlay.borderSubtle
    }

    Item {
        id: contentLayer

        anchors.fill: parent
        anchors.margins: chromePadding
    }

    Behavior on opacity {
        NumberAnimation {
            duration: panel.active ? StylePopover.showDuration : StylePopover.hideDuration
            easing.type: panel.active ? Easing.OutCubic : Easing.InCubic
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: panel.active ? StylePopover.showDuration : StylePopover.hideDuration
            easing.type: Easing.OutBack
            easing.overshoot: 0.5
        }

    }

}
