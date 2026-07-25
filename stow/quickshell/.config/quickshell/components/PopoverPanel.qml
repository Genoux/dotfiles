import Qt5Compat.GraphicalEffects
import QtQuick
import qs.config

// Popover panel surface — floats above the bar with all four corners rounded.
// Uses the translucent overlay material: the Hyprland layer rule for the quickshell
// namespace sets blur_popups, so popup windows receive the same compositor blur as the bar.
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

    property real revealOpacity: 0
    property real revealScale: StylePopover.hiddenScale

    // visual transform only — does not affect implicitWidth/Height or PopupWindow anchor math
    opacity: revealOpacity
    scale: revealScale
    transformOrigin: Item.Bottom

    onActiveChanged: {
        if (active) {
            hideAnimation.stop()
            showAnimation.start()
        } else {
            showAnimation.stop()
            hideAnimation.start()
        }
    }

    DropShadow {
        anchors.fill: surface
        source: surface
        horizontalOffset: 0
        verticalOffset: 0
        radius: 8
        samples: 17
        color: StyleOverlay.shadow
        opacity: panel.revealOpacity
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

    ParallelAnimation {
        id: showAnimation

        NumberAnimation {
            target: panel
            property: "revealOpacity"
            to: 1
            duration: StylePopover.showDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: panel
            property: "revealScale"
            to: 1
            duration: StylePopover.showDuration
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: hideAnimation

        NumberAnimation {
            target: panel
            property: "revealOpacity"
            to: 0
            duration: StylePopover.hideDuration
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: panel
            property: "revealScale"
            to: StylePopover.hiddenScale
            duration: StylePopover.hideDuration
            easing.type: Easing.InCubic
        }
    }
}
