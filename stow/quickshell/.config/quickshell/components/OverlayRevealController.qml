import QtQuick
import qs.config

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property bool active: false
    property real revealOpacity: 0
    property real revealScale: Style.overlayHiddenScale

    signal hideFinished()

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

    ParallelAnimation {
        id: showAnimation

        NumberAnimation {
            target: root
            property: "revealOpacity"
            to: 1
            duration: Style.overlayShowDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "revealScale"
            to: 1
            duration: Style.overlayShowDuration
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: hideAnimation

        NumberAnimation {
            target: root
            property: "revealOpacity"
            to: 0
            duration: Style.overlayHideDuration
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "revealScale"
            to: Style.overlayHiddenScale
            duration: Style.overlayHideDuration
            easing.type: Easing.InCubic
        }

        onStopped: {
            if (!root.active)
                root.hideFinished()
        }
    }
}
