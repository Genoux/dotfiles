import QtQuick
import Qt5Compat.GraphicalEffects
import qs.config

Item {
    id: root

    property bool active: false
    property color surfaceColor: StyleOverlay.surface
    property color surfaceBorderColor: StyleOverlay.surfaceBorder

    default property alias content: contentLayer.data

    signal hideFinished()

    opacity: 1
    scale: revealScaleValue
    transformOrigin: Item.Center

    property real revealOpacityValue: 0
    property real revealScaleValue: StyleOverlay.hiddenScale

    function show() {
        hideAnimation.stop()
        showAnimation.start()
    }

    function hide() {
        hideAnimation.start()
    }

    function stopHide() {
        hideAnimation.stop()
    }

    DropShadow {
        anchors.fill: surface
        source: surface
        horizontalOffset: StyleTokens.space6
        verticalOffset: StyleTokens.space6
        radius: StyleTokens.space10
        // Render-quality knob, not a design dimension.
        samples: 21
        color: StyleOverlay.shadow
        opacity: root.revealOpacityValue
        transparentBorder: true
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: StyleTokens.radiusMd
        color: root.surfaceColor
        border.width: StyleTokens.borderWidth
        border.color: root.surfaceBorderColor
        opacity: root.revealOpacityValue
    }

    Item {
        id: contentLayer

        anchors.fill: parent
        opacity: root.revealOpacityValue
    }

    ParallelAnimation {
        id: showAnimation

        NumberAnimation {
            target: root
            property: "revealOpacityValue"
            to: 1
            duration: StyleOverlay.showDuration
            easing.type: StyleTokens.easeStandard
        }

        NumberAnimation {
            target: root
            property: "revealScaleValue"
            to: 1
            duration: StyleOverlay.showDuration
            easing.type: StyleTokens.easeStandard
        }
    }

    ParallelAnimation {
        id: hideAnimation

        NumberAnimation {
            target: root
            property: "revealOpacityValue"
            to: 0
            duration: StyleOverlay.hideDuration
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "revealScaleValue"
            to: StyleOverlay.hiddenScale
            duration: StyleOverlay.hideDuration
            easing.type: Easing.InCubic
        }

        onStopped: {
            if (!root.active)
                root.hideFinished()
        }
    }
}
