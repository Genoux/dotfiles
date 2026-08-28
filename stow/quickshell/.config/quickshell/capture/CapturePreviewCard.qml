import QtQuick
import Quickshell.Widgets
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
    border.color: StyleCapture.border

    onHoveredChanged: {
        if (hovered)
            expireTimer.stop();
        else
            expireTimer.restart();
    }

    Component.onCompleted: expireTimer.restart()

    component CardAction: Button {
        iconSize: StyleControl.iconSizeMd
        radius: height / 2
        paddingHorizontal: StyleCapture.actionPadding
        paddingVertical: StyleCapture.actionPadding
        interactive: root.hovered
    }

    Timer {
        id: expireTimer

        interval: StyleCapture.previewTimeout
        repeat: false
        onTriggered: Services.CaptureState.dismiss()
    }

    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: StyleTokens.borderWidth
        radius: root.radius - StyleTokens.borderWidth
        color: StyleTokens.transparent

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

        // Dimming the capture is what makes icons over a photograph legible at
        // all; without it the glyphs compete with whatever was on screen.
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

        CardAction {
            iconSource: IconRegistry.captureIcon("copy")
            onClicked: Services.CaptureState.copyLatest()
        }

        CardAction {
            iconSource: root.isVideo
                ? IconRegistry.captureIcon("play")
                : IconRegistry.captureIcon("edit")
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
    CardAction {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: StyleTokens.space8
        iconName: "window-close-symbolic"
        opacity: root.hovered ? 1 : 0
        onClicked: Services.CaptureState.dismiss()

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.easeDurationFast
                easing.type: StyleTokens.easeStandard
            }
        }
    }
}
