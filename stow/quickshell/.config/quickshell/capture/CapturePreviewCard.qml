import QtQuick
import qs
import qs.components
import qs.config
import qs.services as Services

// What just got captured, with the three things you might do about it. Follows
// the notification contract rather than the popover one: hover pauses expiry
// instead of pretending the whole card is a button.
Rectangle {
    id: root

    property bool hovered: false
    property bool confirmingDiscard: false

    readonly property bool isVideo: Services.CaptureState.latestIsVideo
    readonly property string thumbnail: Services.CaptureState.thumbnailSource

    width: StyleCapture.cardWidth
    implicitHeight: content.implicitHeight + StyleNotification.padding * 2
    height: implicitHeight
    radius: StyleTokens.radiusMd
    color: StyleNotification.surface
    border.width: StyleTokens.borderWidth
    border.color: StyleNotification.border

    onHoveredChanged: {
        if (hovered) {
            expireTimer.stop();
            return;
        }
        confirmingDiscard = false;
        expireTimer.restart();
    }

    Component.onCompleted: expireTimer.restart()

    Timer {
        id: expireTimer

        interval: StyleCapture.previewTimeout
        repeat: false
        onTriggered: Services.CaptureState.dismiss()
    }

    // Declared before the content so the action controls above it take clicks
    // first; this only tracks hover for the expiry pause.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.hovered = true
        onExited: root.hovered = false
    }

    Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: StyleNotification.padding
        spacing: StyleTokens.space8

        Rectangle {
            width: parent.width
            height: StyleCapture.thumbnailHeight
            radius: StyleTokens.radiusSm
            color: StyleTokens.alphaHairline
            clip: true

            Image {
                anchors.fill: parent
                visible: root.thumbnail.length > 0
                source: root.thumbnail
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // The path is reused across captures of the same name, so a
                // cached frame would outlive the file it came from.
                cache: false
            }

            // A recording's poster frame is extracted asynchronously, so the
            // card opens before there is anything to show.
            PopoverMessage {
                anchors.centerIn: parent
                width: parent.width
                visible: root.thumbnail.length === 0
                text: root.isVideo ? "Rendering preview…" : "No preview"
            }

            Rectangle {
                anchors.centerIn: parent
                visible: root.isVideo && root.thumbnail.length > 0
                width: StyleControl.iconSize * 2
                height: width
                radius: width / 2
                color: StyleOverlay.surface

                ThemedIcon {
                    anchors.centerIn: parent
                    source: IconRegistry.captureIcon("play")
                }
            }
        }

        Text {
            width: parent.width
            text: Services.CaptureState.latestName
            color: Colors.base05
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeSm
            elide: Text.ElideMiddle
        }

        Item {
            width: parent.width
            height: actionRow.implicitHeight

            Row {
                id: actionRow

                spacing: StyleTokens.space8

                PillButton {
                    iconSource: IconRegistry.captureIcon("copy")
                    text: "Copy"
                    onClicked: Services.CaptureState.copyLatest()
                }

                PillButton {
                    iconSource: root.isVideo
                        ? IconRegistry.captureIcon("play")
                        : IconRegistry.captureIcon("edit")
                    text: root.isVideo ? "Play" : "Edit"
                    onClicked: {
                        if (root.isVideo)
                            Services.CaptureState.openLatest();
                        else
                            Services.CaptureState.editLatest();
                    }
                }
            }

            // Deleting a file is not reversible by the control that did it, so
            // it arms into a worded confirm rather than acting on first click —
            // the same contract RowActions gives a list row's destructive slot.
            PillButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconSource: root.confirmingDiscard ? "" : IconRegistry.captureIcon("discard")
                text: root.confirmingDiscard ? "Delete" : ""
                paddingHorizontal: root.confirmingDiscard
                    ? StylePopover.pillPaddingH
                    : StylePopover.iconButtonPadding
                paddingVertical: root.confirmingDiscard
                    ? StylePopover.pillPaddingV
                    : StylePopover.iconButtonPadding
                onClicked: {
                    if (root.confirmingDiscard)
                        Services.CaptureState.discardLatest();
                    else
                        root.confirmingDiscard = true;
                }
            }
        }
    }
}
