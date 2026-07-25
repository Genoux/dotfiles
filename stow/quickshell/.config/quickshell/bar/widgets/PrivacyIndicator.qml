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

    visible: Privacy.anyActive
    spacing: 1

    HyprlandFocusGrab {
        id: tooltipGrab

        active: root.tooltipVisible && root.barWindow !== null
        windows: [root.barWindow, tooltipWindow]
        onCleared: root.hideTooltip()
    }

    // Tooltip uses PopupWindow directly — it is hover-driven (not a toggle),
    // does not grab focus, and needs custom HyprlandFocusGrab for dismissal.
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

    Button {
        id: webcamButton

        visible: Privacy.webcam
        iconName: "camera-video"
        background: StylePrivacy.webcamFill
        hoverBackground: StylePrivacy.webcamFill
        borderWidth: 1
        borderColor: StylePrivacy.webcamBorder
        onHoveredChanged: {
            if (hovered)
                root.showTooltip(webcamButton, Privacy.webcamSource, "Camera");
            else
                root.hideTooltipIfNeeded();
        }
    }

    Button {
        id: micButton

        visible: Privacy.mic
        iconName: "mic-on"
        background: StylePrivacy.micFill
        hoverBackground: StylePrivacy.micFill
        borderWidth: 1
        borderColor: StylePrivacy.micBorder
        onHoveredChanged: {
            if (hovered)
                root.showTooltip(micButton, Privacy.micSource, "Microphone");
            else
                root.hideTooltipIfNeeded();
        }
    }

    Button {
        id: screenButton

        visible: Privacy.screenAccess
        iconName: "monitor-video"
        background: StylePrivacy.screenFill
        hoverBackground: StylePrivacy.screenFill
        borderWidth: 1
        borderColor: StylePrivacy.screenBorder
        onHoveredChanged: {
            if (hovered)
                root.showTooltip(screenButton, Privacy.screenSource, "Screen sharing");
            else
                root.hideTooltipIfNeeded();
        }
    }
}
