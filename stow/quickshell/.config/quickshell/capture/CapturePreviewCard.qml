import QtQuick
import qs
import qs.components
import qs.config
import qs.services as Services

// What just got captured. The thumbnail IS the card — the filename told you
// nothing you could not see, so the actions live over the image and appear only
// when you reach for them. Follows the notification contract rather than the
// popover one: hover pauses expiry instead of treating the card as a button.
Rectangle {
    id: root

    property bool hovered: false

    readonly property bool isVideo: Services.CaptureState.latestIsVideo
    readonly property string thumbnail: Services.CaptureState.thumbnailSource

    width: StyleCapture.cardWidth
    implicitHeight: StyleCapture.thumbnailHeight
    height: implicitHeight
    radius: StyleTokens.radiusMd
    color: StyleNotification.surface
    border.width: StyleTokens.borderWidth
    border.color: StyleNotification.border
    clip: true

    onHoveredChanged: {
        if (hovered)
            expireTimer.stop();
        else
            expireTimer.restart();
    }

    Component.onCompleted: expireTimer.restart()

    Timer {
        id: expireTimer

        interval: StyleCapture.previewTimeout
        repeat: false
        onTriggered: Services.CaptureState.dismiss()
    }

    Image {
        anchors.fill: parent
        visible: root.thumbnail.length > 0
        source: root.thumbnail
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // The poster path is derived from the file name, so a cached frame
        // would outlive the capture it came from.
        cache: false
    }

    // A recording's poster frame is extracted asynchronously, so the card
    // opens before there is anything to show.
    PopoverMessage {
        anchors.centerIn: parent
        width: parent.width
        visible: root.thumbnail.length === 0
        text: root.isVideo ? "Rendering preview…" : "No preview"
    }

    HoverHandler {
        id: hoverHandler

        onHoveredChanged: root.hovered = hoverHandler.hovered
    }

    // Dimming the capture is what makes icons over a photograph legible at all;
    // without it the glyphs compete with whatever was on screen.
    Rectangle {
        anchors.fill: parent
        color: StyleCapture.scrim
        opacity: root.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.easeDurationFast
                easing.type: StyleTokens.easeStandard
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: StyleTokens.space12
        opacity: root.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.easeDurationFast
                easing.type: StyleTokens.easeStandard
            }
        }

        PillButton {
            iconSource: IconRegistry.captureIcon("copy")
            paddingHorizontal: StyleCapture.actionPadding
            paddingVertical: StyleCapture.actionPadding
            interactive: root.hovered
            onClicked: Services.CaptureState.copyLatest()
        }

        PillButton {
            iconSource: root.isVideo
                ? IconRegistry.captureIcon("play")
                : IconRegistry.captureIcon("edit")
            paddingHorizontal: StyleCapture.actionPadding
            paddingVertical: StyleCapture.actionPadding
            interactive: root.hovered
            onClicked: {
                if (root.isVideo)
                    Services.CaptureState.openLatest();
                else
                    Services.CaptureState.editLatest();
            }
        }
    }

    // Dismisses the card and nothing else: the capture stays on disk. It sits
    // apart from the two actions because it acts on this card, not on the file.
    PillButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: StyleTokens.space8
        iconName: "window-close-symbolic"
        iconSize: StyleControl.iconSizeSm
        paddingHorizontal: StylePopover.iconButtonPadding
        paddingVertical: StylePopover.iconButtonPadding
        opacity: root.hovered ? 1 : 0
        interactive: root.hovered
        onClicked: Services.CaptureState.dismiss()

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.easeDurationFast
                easing.type: StyleTokens.easeStandard
            }
        }
    }
}
