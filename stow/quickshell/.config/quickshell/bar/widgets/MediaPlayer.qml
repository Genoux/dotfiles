import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell.Hyprland
import qs
import qs.components
import qs.config
import qs.services as Services

BarGroup {
    id: root

    readonly property var player: Services.MediaPlayers.player
    readonly property string trackText: player ? `${player.trackTitle || player.identity || "Media"}${player.trackArtist ? " - " + player.trackArtist : ""}` : ""
    readonly property bool canGoPrevious: Services.MediaPlayers.canGoPrevious
    readonly property bool canGoNext: Services.MediaPlayers.canGoNext
    readonly property bool canTogglePlayback: Services.MediaPlayers.canTogglePlayback
    property bool controlsExpanded: false

    function playerMatchTokens(player) {
        const desktopEntry = String(player.desktopEntry || "").replace(/\.desktop$/i, "").toLowerCase();
        const identity = String(player.identity || "").toLowerCase();
        return Array.from(new Set([desktopEntry, identity].concat(desktopEntry.split(/[._-]+/)).concat(identity.split(/[._-]+/)))).filter((token) => {
            return token.length > 2;
        });
    }

    function focusToplevel(toplevel) {
        if (!toplevel)
            return false;

        if (toplevel.wayland) {
            toplevel.wayland.activate();
            return true;
        }
        const address = toplevel.lastIpcObject ? toplevel.lastIpcObject.address : undefined;
        if (address) {
            ShellActions.focusWindow(`address:${address}`);
            return true;
        }
        return false;
    }

    function focusPlayerHyprlandWindow(player) {
        const tokens = playerMatchTokens(player);
        if (tokens.length > 0) {
            const classMatch = Hyprland.toplevels.values.find((toplevel) => {
                const cls = String((toplevel.wayland && toplevel.wayland.appId) || (toplevel.lastIpcObject && toplevel.lastIpcObject.class) || "").toLowerCase();
                const initialClass = String(toplevel.lastIpcObject ? toplevel.lastIpcObject.initialClass : "").toLowerCase();
                return tokens.some((token) => {
                    return cls.includes(token) || initialClass.includes(token) || token.includes(cls);
                });
            });
            if (focusToplevel(classMatch))
                return true;

        }
        const trackTitle = String(player.trackTitle || "").trim();
        if (trackTitle.length < 3)
            return false;

        const normalizedTitle = trackTitle.toLowerCase();
        const titleMatch = Hyprland.toplevels.values.find((toplevel) => {
            return String(toplevel.title || "").toLowerCase().includes(normalizedTitle);
        });
        return focusToplevel(titleMatch);
    }

    function focusPlayerWindow() {
        if (!root.player)
            return ;

        Services.MediaPlayers.markPlayerInteracted();
        if (root.player.canRaise)
            root.player.raise();

        focusPlayerHyprlandWindow(root.player);
    }

    visible: player !== null && trackText.length > 0

    HoverHandler {
        id: hoverHandler

        onHoveredChanged: {
            if (hovered) {
                controlsRevealTimer.restart();
            } else {
                controlsRevealTimer.stop();
                root.controlsExpanded = false;
            }
        }
    }

    Timer {
        id: controlsRevealTimer

        interval: StyleMedia.controlsHoverDelay
        onTriggered: root.controlsExpanded = true
    }

    Row {
        id: contentRow

        height: StyleMedia.trackHeight
        spacing: root.controlsExpanded ? StyleTokens.space3 : 0

        Rectangle {
            id: mediaInfo

            readonly property real textLeftInset: StyleMedia.textLeftInset
            readonly property real textRightInset: StyleMedia.textRightInset
            readonly property real textViewportLeftMargin: textLeftInset + StyleTokens.space2
            readonly property real textViewportRightMargin: StyleTokens.space6
            readonly property string scrollText: `${root.trackText} • `
            readonly property real singleTextWidth: mediaMeasure.advanceWidth
            readonly property real textViewportMaxWidth: StyleMedia.infoWidth - textLeftInset - textRightInset
            readonly property bool shouldScroll: singleTextWidth > textViewportMaxWidth
            readonly property real fittedWidth: textLeftInset + singleTextWidth + textRightInset

            width: shouldScroll ? StyleMedia.infoWidth : fittedWidth
            implicitWidth: width
            height: contentRow.height
            radius: StyleTokens.radiusSm
            color: hoverHandler.hovered ? StyleTokens.alphaLight : StyleTokens.transparent
            onScrollTextChanged: scrollAnimation.restart()

            CavaVisualizer {
                anchors.left: parent.left
                anchors.leftMargin: StyleTokens.space6
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.visible
                active: root.player ? root.player.isPlaying : false
            }

            Item {
                id: textViewport

                readonly property real edgeFade: Math.min(StyleMedia.textFadeWidth / Math.max(width, 1), 0.2)

                anchors.left: parent.left
                anchors.leftMargin: mediaInfo.textViewportLeftMargin
                anchors.right: parent.right
                anchors.rightMargin: mediaInfo.textViewportRightMargin
                anchors.verticalCenter: parent.verticalCenter
                height: mediaLabel.implicitHeight

                Item {
                    id: textLayer

                    anchors.fill: parent
                    clip: true
                    layer.enabled: mediaInfo.shouldScroll
                    layer.smooth: true

                    Text {
                        id: mediaLabel

                        // The label holds two copies of the text, so sliding it
                        // left by exactly one copy lands back where it started.
                        readonly property real loopWidth: implicitWidth / 2
                        property real scrollOffset: 0

                        // Translate rather than x: the edge fade needs
                        // layer.enabled, and inside a layer a child's x is
                        // rasterized onto the texture's whole-pixel grid. At this
                        // speed one pixel takes ~48ms, so the marquee visibly
                        // stepped about twenty times a second. A transform is
                        // applied to the node instead and keeps sub-pixel offsets.
                        transform: Translate {
                            x: mediaInfo.shouldScroll ? -mediaLabel.scrollOffset : 0
                        }
                        text: mediaInfo.shouldScroll ? mediaInfo.scrollText + mediaInfo.scrollText : root.trackText
                        color: Colors.base05
                        font.family: StyleTokens.fontMono
                        font.pixelSize: StyleTokens.fontSizeMedia

                        // A Timer is not tied to the frame clock: at 17ms against
                        // a 144Hz panel it landed on every second or third frame in
                        // turn. An animation is advanced once per frame at whatever
                        // the refresh rate is, which is why the speed token is per
                        // second rather than per tick.
                        NumberAnimation on scrollOffset {
                            id: scrollAnimation

                            running: mediaInfo.shouldScroll && root.visible
                            loops: Animation.Infinite
                            from: 0
                            to: mediaLabel.loopWidth
                            duration: Math.max(1, mediaLabel.loopWidth / StyleMedia.scrollSpeed * 1000)
                        }
                    }

                    layer.effect: OpacityMask {
                        maskSource: textFadeMask
                    }

                }

                Rectangle {
                    id: textFadeMask

                    anchors.fill: parent
                    visible: false

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            // Alpha-only mask stops are structural, not theme colours.
                            color: StyleTokens.transparent
                        }

                        GradientStop {
                            position: textViewport.edgeFade
                            color: "#ffffffff"
                        }

                        GradientStop {
                            position: 1 - textViewport.edgeFade
                            color: "#ffffffff"
                        }

                        GradientStop {
                            position: 1
                            color: StyleTokens.transparent
                        }

                    }

                }

            }

            TextMetrics {
                id: mediaMeasure

                text: root.trackText
                font.family: StyleTokens.fontMono
                font.pixelSize: StyleTokens.fontSizeMedia
            }

            MouseArea {
                id: mediaMouse

                anchors.fill: parent
                acceptedButtons: root.player ? Qt.LeftButton : Qt.NoButton
                cursorShape: root.player ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: true
                onClicked: root.focusPlayerWindow()
            }

            Behavior on color {
                ColorAnimation {
                    duration: StyleMedia.controlsRevealDuration
                    easing.type: StyleTokens.easeStandard
                }

            }

            Behavior on width {
                NumberAnimation {
                    duration: StyleMedia.controlsRevealDuration
                    easing.type: StyleTokens.easeStandard
                }

            }

        }

        Item {
            id: controlsReveal

            height: StyleMedia.trackHeight
            width: root.controlsExpanded ? controlsRow.implicitWidth : 0
            clip: true

            Row {
                id: controlsRow

                height: StyleMedia.trackHeight
                spacing: 0
                opacity: root.controlsExpanded ? 1 : 0

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    iconSource: IconRegistry.mediaIcon("skip-backward")
                    iconSize: StyleControl.iconSizeSm
                    interactive: root.controlsExpanded && root.canGoPrevious
                    onClicked: Services.MediaPlayers.previous()
                }

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    iconSource: IconRegistry.mediaIcon(player && player.isPlaying ? "pause" : "play")
                    iconSize: StyleControl.iconSizeSm
                    interactive: root.controlsExpanded && root.canTogglePlayback
                    onClicked: Services.MediaPlayers.togglePlayback()
                }

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    iconSource: IconRegistry.mediaIcon("skip-forward")
                    iconSize: StyleControl.iconSizeSm
                    interactive: root.controlsExpanded && root.canGoNext
                    onClicked: Services.MediaPlayers.next()
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: StyleMedia.controlsRevealDuration
                        easing.type: StyleTokens.easeStandard
                    }

                }

            }

            Behavior on width {
                NumberAnimation {
                    duration: StyleMedia.controlsRevealDuration
                    easing.type: StyleTokens.easeStandard
                }

            }

        }

    }

    Behavior on color {
        ColorAnimation {
            duration: StyleMedia.controlsRevealDuration
            easing.type: StyleTokens.easeStandard
        }

    }

}
