import Quickshell.Services.Mpris
import QtQuick
import Qt5Compat.GraphicalEffects
import qs
import qs.config
import qs.components

BarGroup {
    id: root

    property string explicitPlayerKey: ""
    readonly property var activePlayers: Mpris.players.values.filter((candidate) => candidate.playbackState !== MprisPlaybackState.Stopped)
    readonly property var explicitPlayer: explicitPlayerKey.length > 0 ? activePlayers.find((candidate) => playerKey(candidate) === explicitPlayerKey) ?? null : null
    readonly property var playingPlayer: activePlayers.find((candidate) => candidate.isPlaying) ?? null
    readonly property var player: (explicitPlayer && (explicitPlayer.isPlaying || !playingPlayer)) ? explicitPlayer : playingPlayer ?? activePlayers[0] ?? Mpris.players.values[0] ?? null
    readonly property string trackText: player ? `${player.trackTitle || player.identity || "Media"}${player.trackArtist ? " - " + player.trackArtist : ""}` : ""
    readonly property bool canGoPrevious: player?.canGoPrevious ?? false
    readonly property bool canGoNext: player?.canGoNext ?? false
    readonly property bool canTogglePlayback: player ? (player.isPlaying ? player.canPause : player.canPlay) : false
    property real scrollOffset: 0

    readonly property bool controlsExpanded: hoverHandler.hovered
    readonly property int innerHeight: Style.mediaHeight - chromeInset * 2

    visible: player !== null && trackText.length > 0
    implicitWidth: contentRow.implicitWidth + chromeInset * 2

    Behavior on color {
        ColorAnimation {
            duration: Style.mediaControlsRevealDuration
            easing.type: Easing.OutCubic
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    Row {
        id: contentRow

        anchors.fill: parent
        spacing: root.controlsExpanded ? 3 : 0

        Rectangle {
            id: mediaInfo

            readonly property real textLeftInset: 6 + Style.cavaVisualWidth + 4
            readonly property real textRightInset: 6
            readonly property string scrollText: `${root.trackText} • `
            readonly property real singleTextWidth: mediaMeasure.implicitWidth
            readonly property real textViewportMaxWidth: Style.mediaInfoWidth - textLeftInset - textRightInset
            readonly property bool shouldScroll: singleTextWidth > textViewportMaxWidth
            readonly property real fittedWidth: textLeftInset + singleTextWidth + textRightInset

            width: shouldScroll ? Style.mediaInfoWidth : fittedWidth
            implicitWidth: width
            height: parent.height
            radius: Style.radiusSm
            color: root.controlsExpanded ? Style.alphaLight : Style.transparent

            Behavior on color {
                ColorAnimation {
                    duration: Style.mediaControlsRevealDuration
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: Style.mediaControlsRevealDuration
                    easing.type: Easing.OutCubic
                }
            }

            CavaVisualizer {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.visible
                active: root.player?.isPlaying ?? false
            }

            Item {
                id: textViewport

                anchors.left: parent.left
                anchors.leftMargin: mediaInfo.textLeftInset + 2
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                height: mediaLabel.implicitHeight

                readonly property real edgeFade: Math.min(
                    Style.mediaTextFadeWidth / Math.max(width, 1),
                    0.2
                )

                Item {
                    id: textLayer

                    anchors.fill: parent
                    clip: true
                    layer.enabled: mediaInfo.shouldScroll
                    layer.smooth: true
                    layer.effect: OpacityMask {
                        maskSource: textFadeMask
                    }

                    Text {
                        id: mediaLabel

                        x: mediaInfo.shouldScroll ? -root.scrollOffset : 0
                        text: mediaInfo.shouldScroll ? mediaInfo.scrollText + mediaInfo.scrollText : root.trackText
                        color: Colors.base05
                        font.family: Style.fontMono
                        font.pixelSize: Style.fontSizeMedia
                    }
                }

                Rectangle {
                    id: textFadeMask

                    anchors.fill: parent
                    visible: false
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#00000000" }
                        GradientStop { position: textViewport.edgeFade; color: "#ffffffff" }
                        GradientStop { position: 1 - textViewport.edgeFade; color: "#ffffffff" }
                        GradientStop { position: 1; color: "#00000000" }
                    }
                }
            }

            Text {
                id: mediaMeasure

                visible: false
                text: root.trackText
                font.family: Style.fontMono
                font.pixelSize: Style.fontSizeMedia
            }

            MouseArea {
                id: mediaMouse

                anchors.fill: parent
                acceptedButtons: (root.player?.canRaise ?? false) ? Qt.LeftButton : Qt.NoButton
                cursorShape: (root.player?.canRaise ?? false) ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: true
                onClicked: root.raisePlayer()
            }

            Timer {
                interval: 17
                running: mediaInfo.shouldScroll && root.visible
                repeat: true
                onTriggered: {
                    const loopWidth = mediaLabel.implicitWidth / 2;
                    root.scrollOffset = root.scrollOffset >= loopWidth ? 0 : root.scrollOffset + 0.20;
                }
            }

            onScrollTextChanged: root.scrollOffset = 0
            onShouldScrollChanged: root.scrollOffset = 0
        }

        Item {
            id: controlsReveal

            height: parent.height
            width: root.controlsExpanded ? controlsRow.implicitWidth : 0
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: Style.mediaControlsRevealDuration
                    easing.type: Easing.OutCubic
                }
            }

            Row {
                id: controlsRow

                height: parent.height
                spacing: 0
                opacity: root.controlsExpanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Style.mediaControlsRevealDuration
                        easing.type: Easing.OutCubic
                    }
                }

                IconButton {
                    iconName: "media-skip-backward-symbolic"
                    iconSize: Style.iconSizeSm
                    implicitWidth: root.innerHeight
                    implicitHeight: root.innerHeight
                    interactive: root.controlsExpanded && root.canGoPrevious
                    onClicked: root.previous()
                }

                IconButton {
                    iconName: player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                    iconSize: Style.iconSizeSm
                    implicitWidth: root.innerHeight
                    implicitHeight: root.innerHeight
                    interactive: root.controlsExpanded && root.canTogglePlayback
                    onClicked: root.togglePlayback()
                }

                IconButton {
                    iconName: "media-skip-forward-symbolic"
                    iconSize: Style.iconSizeSm
                    implicitWidth: root.innerHeight
                    implicitHeight: root.innerHeight
                    interactive: root.controlsExpanded && root.canGoNext
                    onClicked: root.next()
                }
            }
        }
    }

    onTrackTextChanged: scrollOffset = 0

    function playerKey(candidate) {
        return candidate ? (candidate.desktopEntry || candidate.identity || "") : ""
    }

    function markPlayerInteracted() {
        explicitPlayerKey = playerKey(root.player)
    }

    function raisePlayer() {
        markPlayerInteracted()
        if (root.player?.canRaise)
            root.player.raise()
    }

    function previous() {
        markPlayerInteracted()
        if (root.player?.canGoPrevious)
            root.player.previous()
    }

    function togglePlayback() {
        if (!root.player)
            return

        markPlayerInteracted()
        if (root.player.isPlaying) {
            if (root.player.canPause)
                root.player.pause()
        } else if (root.player.canPlay) {
            root.player.play()
        }
    }

    function next() {
        markPlayerInteracted()
        if (root.player?.canGoNext)
            root.player.next()
    }
}
