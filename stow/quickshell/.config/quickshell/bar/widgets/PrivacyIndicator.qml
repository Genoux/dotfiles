import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.services

Item {
    id: root

    property var barWindow: null
    // Bound, not set on hover: a source that starts or stops while the
    // pointer rests on the dot must show up in the open tooltip.
    readonly property string tooltipText: [
        Privacy.webcam ? describe("Camera", Privacy.webcamSource) : "",
        Privacy.mic ? describe("Microphone", Privacy.micSource) : "",
        Privacy.screenShared ? describe("Screen", Privacy.screenSource) : ""
    ].filter(line => line.length > 0).join("\n")
    property bool tooltipVisible: false
    property bool tooltipPresented: false
    property real _centerX: 0

    onTooltipVisibleChanged: {
        if (tooltipVisible)
            tooltipPresented = true;
    }

    readonly property bool active: Privacy.webcam || Privacy.mic || Privacy.screenShared
    // One dot for everything, coloured by the most sensitive source.
    readonly property color dotColor: Privacy.webcam ? StylePrivacy.camera
        : Privacy.mic ? StylePrivacy.microphone
        : StylePrivacy.screen

    function describe(label, source) {
        return source.length > 0 ? label + " · " + source : label;
    }

    function showTooltip() {
        root._centerX = root.mapToItem(null, root.width / 2, 0).x;
        root.tooltipVisible = true;
    }

    function hideTooltip() {
        root.tooltipVisible = false;
    }

    visible: active || width > 0
    implicitWidth: active ? StyleControl.buttonHeight : 0
    implicitHeight: StyleControl.buttonHeight
    width: implicitWidth
    height: implicitHeight
    opacity: active ? 1 : 0
    onActiveChanged: {
        if (!active)
            hideTooltip();
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: root.active ? StyleTokens.motionEnterDuration : StyleTokens.motionExitDuration
            easing.type: StyleTokens.easeStandard
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.active ? StyleTokens.motionEnterDuration : StyleTokens.motionExitDuration
            easing.type: StyleTokens.easeFade
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: StylePrivacy.dotSize
        height: StylePrivacy.dotSize
        radius: width / 2
        color: root.dotColor

        Behavior on color {
            ColorAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeFade
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onContainsMouseChanged: containsMouse ? root.showTooltip() : root.hideTooltip()
    }

    HyprlandFocusGrab {
        id: tooltipGrab

        active: root.tooltipVisible && root.barWindow !== null
        windows: [root.barWindow, tooltipWindow]
        onCleared: root.hideTooltip()
    }

    PopupWindow {
        id: tooltipWindow

        readonly property real popW: implicitWidth
        readonly property real popH: implicitHeight

        anchor.window: root.barWindow
        anchor.rect.x: Math.round(Math.max(0, root._centerX - popW / 2))
        anchor.rect.y: Math.round(-popH)
        anchor.rect.width: 1
        anchor.rect.height: 1
        grabFocus: false
        color: StyleTokens.transparent
        visible: root.tooltipPresented && root.tooltipText.length > 0 && root.barWindow !== null
        implicitWidth: tooltipPanel.implicitWidth
        implicitHeight: tooltipPanel.implicitHeight
        onClosed: root.hideTooltip()

        PopoverPanel {
            id: tooltipPanel

            active: root.tooltipVisible && root.tooltipText.length > 0
            fitContent: true
            onDismissFinished: {
                if (!root.tooltipVisible)
                    root.tooltipPresented = false;
            }

            PopoverLabel {
                text: root.tooltipText
            }
        }
    }
}
