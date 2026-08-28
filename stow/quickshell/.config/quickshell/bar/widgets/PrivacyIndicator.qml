import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.services

Row {
    id: root

    property var barWindow: null
    property string tooltipText: ""
    property bool tooltipVisible: false
    property real _centerX: 0

    function showTooltip(button, source, fallback) {
        const label = source.length > 0 ? source : fallback;
        const pt = button.mapToItem(null, button.width / 2, 0);
        root._centerX = pt.x;
        root.tooltipText = label;
        root.tooltipVisible = true;
    }

    function hideTooltip() {
        root.tooltipVisible = false;
    }

    function hideTooltipIfNeeded() {
        if (!webcamButton.hovered && !micButton.hovered && !screenButton.hovered)
            root.hideTooltip();
    }

    visible: Privacy.anyActive || webcamSlot.width > 0 || micSlot.width > 0 || screenSlot.width > 0
    spacing: StyleTokens.space1

    component IndicatorSlot: Item {
        id: slot

        property bool active: false
        default property alias content: slot.data

        visible: active || width > 0
        width: active ? StyleControl.buttonWidth : 0
        height: StyleControl.buttonHeight
        clip: true
        opacity: active ? 1 : 0

        Behavior on width {
            NumberAnimation {
                duration: StyleTokens.easeDurationNormal
                easing.type: StyleTokens.easeStandard
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.easeDurationNormal
                easing.type: StyleTokens.easeStandard
            }
        }
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
        visible: root.tooltipVisible && root.tooltipText.length > 0 && root.barWindow !== null
        implicitWidth: tooltipPanel.implicitWidth
        implicitHeight: tooltipPanel.implicitHeight
        onClosed: root.hideTooltip()

        PopoverPanel {
            id: tooltipPanel

            active: root.tooltipVisible && root.tooltipText.length > 0
            fitContent: true

            PopoverLabel {
                text: root.tooltipText
            }
        }
    }

    IndicatorSlot {
        id: webcamSlot

        active: Privacy.webcam

        Button {
            id: webcamButton

            iconSource: IconRegistry.barControlIcon("camera")
            background: StylePrivacy.webcamFill
            hoverBackground: StylePrivacy.webcamFill
            borderWidth: StyleTokens.borderWidth
            borderColor: StylePrivacy.webcamBorder
            onHoveredChanged: {
                if (hovered)
                    root.showTooltip(webcamButton, Privacy.webcamSource, "Camera");
                else
                    root.hideTooltipIfNeeded();
            }
        }
    }

    IndicatorSlot {
        id: micSlot

        active: Privacy.mic

        Button {
            id: micButton

            iconSource: IconRegistry.barControlIcon("microphone")
            background: StylePrivacy.micFill
            hoverBackground: StylePrivacy.micFill
            borderWidth: StyleTokens.borderWidth
            borderColor: StylePrivacy.micBorder
            onHoveredChanged: {
                if (hovered)
                    root.showTooltip(micButton, Privacy.micSource, "Microphone");
                else
                    root.hideTooltipIfNeeded();
            }
        }
    }

    IndicatorSlot {
        id: screenSlot

        active: Privacy.screenAccess

        Button {
            id: screenButton

            iconSource: IconRegistry.barControlIcon("display")
            background: StylePrivacy.screenFill
            hoverBackground: StylePrivacy.screenFill
            borderWidth: StyleTokens.borderWidth
            borderColor: StylePrivacy.screenBorder
            onHoveredChanged: {
                if (hovered)
                    root.showTooltip(screenButton, Privacy.screenSource, Privacy.recording ? "Recording" : "Screen sharing");
                else
                    root.hideTooltipIfNeeded();
            }
        }
    }
}
