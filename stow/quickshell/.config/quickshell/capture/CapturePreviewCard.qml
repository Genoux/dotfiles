import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.components
import qs.config
import qs.services as Services

// What just got captured. The thumbnail IS the card — the filename told you
// nothing you could not see, so the actions live over the image and appear only
// when you reach for them. Follows the notification contract rather than the
// popover one: hover pauses expiry instead of treating the card as a button.
//
// Owns its poster, timer, and drag: a stack shows several at once, each
// expiring and dismissing on its own schedule.
Rectangle {
    id: root

    required property string path

    // Any card in the stack being pointed at holds the whole stack: expiring the
    // neighbours while you reach across them moves the target under your hand.
    property bool stackHovered: false
    property bool hovered: false
    property bool copied: false
    property bool posterReady: false
    // Rests at the left of a window widened by the drag runway, so x is free to
    // travel right without an anchor fighting it.
    property real restingX: 0

    readonly property string name: Services.CaptureState.nameOf(path)
    readonly property bool isVideo: Services.CaptureState.isVideo(path)
    readonly property string posterPath: `/tmp/qs-capture-poster-${name}.jpg`
    // A video needs a frame extracted before it can be shown; an image is its
    // own thumbnail.
    readonly property string thumbnail: {
        if (path.length === 0)
            return "";
        if (!isVideo)
            return `file://${path}`;
        return posterReady ? `file://${posterPath}` : "";
    }

    readonly property real dragOffset: Math.max(0, x - restingX)
    readonly property bool dragging: dragArea.drag.active
    readonly property bool holding: stackHovered || copied || dragging

    width: StyleCapture.cardWidth
    implicitHeight: StyleCapture.thumbnailHeight
    height: implicitHeight
    x: restingX
    // Fades as it travels, so a release past the threshold finishes a movement
    // already underway rather than cutting one short.
    opacity: 1 - Math.min(1, dragOffset / StyleNotification.dragRunway)
    radius: StyleTokens.radiusMd
    color: StyleNotification.surface
    border.width: StyleTokens.borderWidth
    border.color: StyleCapture.border

    onHoldingChanged: {
        if (holding) {
            expireTimer.stop();
            return;
        }
        expireTimer.restart();
    }

    Component.onCompleted: {
        expireTimer.restart();
        if (isVideo)
            posterProcess.running = true;
    }

    // A burst of captures should survive long enough to act on: the stack lives
    // eight seconds from the last one, not from each card's own arrival, or the
    // early shots expire while you are still taking the later ones.
    Connections {
        target: Services.CaptureState

        function onCapturesChanged() {
            if (!root.holding)
                expireTimer.restart();
        }
    }

    Timer {
        id: expireTimer

        interval: StyleCapture.previewTimeout
        repeat: false
        onTriggered: Services.CaptureState.remove(root.path)
    }

    // Confirms the copy landed before the card goes: one that just vanishes
    // leaves you wondering whether the click registered.
    Timer {
        id: copiedTimer

        interval: StyleCapture.copiedHold
        repeat: false
        onTriggered: Services.CaptureState.remove(root.path)
    }

    Process {
        id: posterProcess

        command: [
            "ffmpeg", "-y", "-i", root.path,
            "-vframes", "1",
            "-vf", `scale=${StyleCapture.posterWidth}:-1`,
            root.posterPath
        ]

        onExited: (code) => root.posterReady = code === 0
    }

    component CardAction: Button {
        iconSize: StyleControl.iconSizeMd
        radius: height / 2
        paddingHorizontal: StyleCapture.actionPadding
        paddingVertical: StyleCapture.actionPadding
        interactive: root.hovered
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

    // A recording's poster frame is extracted asynchronously, so the card opens
    // before there is anything to show.
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

    // Declared before the actions so their own MouseAreas take clicks first;
    // this only claims the drag.
    MouseArea {
        id: dragArea

        anchors.fill: parent
        drag.target: root
        drag.axis: Drag.XAxis
        drag.minimumX: root.restingX
        drag.maximumX: root.restingX + StyleNotification.dragRunway
        drag.filterChildren: true

        onPressed: {
            expireTimer.stop();
            returnAnimation.stop();
        }
        onReleased: {
            if (root.dragOffset >= StyleNotification.dragThreshold) {
                dismissAnimation.restart();
                return;
            }
            returnAnimation.restart();
            if (!root.holding)
                expireTimer.restart();
        }
    }

    NumberAnimation {
        id: returnAnimation

        target: root
        property: "x"
        to: root.restingX
        duration: StyleTokens.easeDurationFast
        easing.type: StyleTokens.easeStandard
    }

    NumberAnimation {
        id: dismissAnimation

        target: root
        property: "x"
        to: root.restingX + StyleNotification.dragRunway
        duration: StyleTokens.easeDurationFast
        easing.type: StyleTokens.easeStandard
        onFinished: Services.CaptureState.remove(root.path)
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
            iconSource: IconRegistry.captureIcon(root.copied ? "copied" : "copy")
            onClicked: {
                if (root.copied)
                    return;
                Services.CaptureState.copy(root.path);
                root.copied = true;
                expireTimer.stop();
                copiedTimer.restart();
            }
        }

        // Only for stills: a recording's Play below already opens it, and two
        // buttons doing the same thing is worse than one.
        CardAction {
            visible: !root.isVideo
            iconSource: IconRegistry.captureIcon("view")
            onClicked: Services.CaptureState.open(root.path)
        }

        CardAction {
            iconSource: root.isVideo
                ? IconRegistry.captureIcon("play")
                : IconRegistry.captureIcon("edit")
            onClicked: {
                if (root.isVideo)
                    Services.CaptureState.open(root.path);
                else
                    Services.CaptureState.edit(root.path);
            }
        }
    }

    // Dismisses the card and nothing else: the capture stays on disk. It sits
    // apart from the two actions because it acts on this card, not the file.
    CardAction {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: StyleTokens.space8
        iconName: "window-close-symbolic"
        opacity: root.hovered ? 1 : 0
        onClicked: Services.CaptureState.remove(root.path)

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.easeDurationFast
                easing.type: StyleTokens.easeStandard
            }
        }
    }
}
