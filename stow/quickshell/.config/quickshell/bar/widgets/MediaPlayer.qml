import Quickshell.Services.Mpris
import QtQuick
import qs
import qs.config
import qs.components
Rectangle {
    id: root

    property string explicitPlayerKey: ""
    readonly property var activePlayers: Mpris.players.values.filter((candidate) => candidate.playbackState !== MprisPlaybackState.Stopped)
    readonly property var explicitPlayer: explicitPlayerKey.length > 0 ? activePlayers.find((candidate) => playerKey(candidate) === explicitPlayerKey) ?? null : null
    readonly property var player: explicitPlayer ?? activePlayers.find((candidate) => candidate.isPlaying) ?? activePlayers[0] ?? Mpris.players.values[0] ?? null
    readonly property string trackText: player ? `${player.trackTitle || player.identity || "Media"}${player.trackArtist ? " - " + player.trackArtist : ""}` : ""
    readonly property bool canGoPrevious: player?.canGoPrevious ?? false
    readonly property bool canGoNext: player?.canGoNext ?? false
    readonly property bool canTogglePlayback: player ? (player.isPlaying ? player.canPause : player.canPlay) : false
    property real scrollOffset: 0

    readonly property bool controlsExpanded: hoverHandler.hovered

    readonly property real borderOpacity: 0.1
    readonly property real chromeInset: border.width + Style.mediaPadding
    readonly property int innerHeight: Style.mediaHeight - chromeInset * 2

    visible: player !== null && trackText.length > 0
    implicitWidth: content.implicitWidth + chromeInset * 2
    implicitHeight: Style.mediaHeight
    height: implicitHeight
    border.width: 1
    border.color: Qt.rgba(Colors.base04.r, Colors.base04.g, Colors.base04.b, borderOpacity)
    radius: Style.radiusMd
    color: Style.transparent
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
        id: content

        anchors.fill: parent
        anchors.margins: chromeInset
        spacing: root.controlsExpanded ? 3 : 0

        Rectangle {
            id: mediaInfo

            readonly property string scrollText: `${root.trackText} • `
            readonly property real singleTextWidth: mediaMeasure.implicitWidth
            readonly property bool shouldScroll: singleTextWidth > textViewport.width

            width: Style.mediaInfoWidth
            height: parent.height
            radius: Style.radiusSm
            color: root.controlsExpanded ? Style.alphaLight : Style.transparent

            Behavior on color {
                ColorAnimation {
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
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                height: mediaLabel.implicitHeight
                clip: true

                Text {
                    id: mediaLabel

                    x: mediaInfo.shouldScroll ? -root.scrollOffset : 0
                    text: mediaInfo.shouldScroll ? mediaInfo.scrollText + mediaInfo.scrollText : root.trackText
                    color: Colors.base05
                    font.family: Style.fontMono
                    font.pixelSize: 11
                }
            }

            Text {
                id: mediaMeasure

                visible: false
                text: root.trackText
                font.family: Style.fontMono
                font.pixelSize: 11
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
