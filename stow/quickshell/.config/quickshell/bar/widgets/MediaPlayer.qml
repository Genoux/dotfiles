import Quickshell.Services.Mpris
import QtQuick
import qs
import qs.config
import qs.components
Row {
    id: root

    readonly property var player: Mpris.players.values.find((candidate) => candidate.isPlaying) ?? Mpris.players.values.find((candidate) => candidate.playbackState !== MprisPlaybackState.Stopped) ?? Mpris.players.values[0] ?? null
    readonly property string trackText: player ? `${player.trackTitle || player.identity || "Media"}${player.trackArtist ? " - " + player.trackArtist : ""}` : ""
    readonly property bool canGoPrevious: player?.canGoPrevious ?? false
    readonly property bool canGoNext: player?.canGoNext ?? false
    readonly property bool canTogglePlayback: player ? (player.isPlaying ? player.canPause : player.canPlay) : false
    property real scrollOffset: 0

    visible: player !== null && trackText.length > 0
    spacing: 3

    Rectangle {
        id: mediaInfo

        readonly property string scrollText: `${root.trackText} • `
        readonly property bool shouldScroll: mediaMeasure.implicitWidth > textViewport.width

        width: 126
        implicitHeight: Style.pillHeight
        radius: Style.radiusSm
        color: mediaMouse.containsMouse ? Style.alphaLight : Style.transparent

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
            anchors.leftMargin: 25
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
                root.scrollOffset = root.scrollOffset >= loopWidth ? 0 : root.scrollOffset + 0.35;
            }
        }

        onScrollTextChanged: root.scrollOffset = 0
        onShouldScrollChanged: root.scrollOffset = 0
    }

    Row {
        spacing: 0

        IconButton {
            iconName: "media-skip-backward-symbolic"
            iconSize: Style.iconSizeSm
            interactive: root.canGoPrevious
            onClicked: root.previous()
        }

        IconButton {
            iconName: player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            iconSize: Style.iconSizeSm
            interactive: root.canTogglePlayback
            onClicked: root.togglePlayback()
        }

        IconButton {
            iconName: "media-skip-forward-symbolic"
            iconSize: Style.iconSizeSm
            interactive: root.canGoNext
            onClicked: root.next()
        }
    }

    onTrackTextChanged: scrollOffset = 0

    function raisePlayer() {
        if (root.player?.canRaise)
            root.player.raise()
    }

    function previous() {
        if (root.player?.canGoPrevious)
            root.player.previous()
    }

    function togglePlayback() {
        if (!root.player)
            return

        if (root.player.isPlaying) {
            if (root.player.canPause)
                root.player.pause()
        } else if (root.player.canPlay) {
            root.player.play()
        }
    }

    function next() {
        if (root.player?.canGoNext)
            root.player.next()
    }
}
