import QtQuick
import QtQuick.Layouts
import qs
import qs.bar.widgets as Widgets
import qs.components
import qs.config
import qs.services as Services

Item {
    id: root

    property bool active: false

    readonly property var players: Services.MediaPlayers.activePlayers
    readonly property var player: Services.MediaPlayers.player
    readonly property string title: player ? Services.MediaPlayers.cleanField(player.trackTitle) : ""
    readonly property string artist: player ? Services.MediaPlayers.cleanField(player.trackArtist) : ""
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real position: player && player.positionSupported ? player.position : 0
    readonly property bool seekable: length > 0 && !Services.MediaPlayers.isLiveStream(player)
    readonly property bool canChoose: players.length > 1
    signal pageRequested(string requestedPage)

    implicitWidth: StyleIsland.pageWidth
    implicitHeight: column.implicitHeight + StyleIsland.pagePaddingTop + StyleIsland.pagePaddingBottom
    width: implicitWidth
    height: implicitHeight

    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor(total % 3600 / 60);
        const pad = (value) => String(value).padStart(2, "0");
        return hours > 0 ? `${hours}:${pad(minutes)}:${pad(total % 60)}` : `${minutes}:${pad(total % 60)}`;
    }

    Timer {
        interval: StyleIsland.positionPollInterval
        repeat: true
        running: root.active && !!root.player && root.player.isPlaying && root.player.positionSupported
        onTriggered: root.player.positionChanged()
    }

    ColumnLayout {
        id: column

        x: StyleIsland.pagePaddingH
        y: StyleIsland.pagePaddingTop
        width: parent.width - StyleIsland.pagePaddingH * 2
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: StyleTokens.space12

            ArtImage {
                Layout.preferredWidth: StyleIsland.artSize
                Layout.preferredHeight: StyleIsland.artSize
                radius: StyleIsland.artRadius
                source: Services.MediaPlayers.artUrl(root.player)
                isIcon: Services.MediaPlayers.isSiteIcon(root.player)

                // The way to the other sources, shown on hover rather than
                // standing on the page as chrome.
                Rectangle {
                    anchors.fill: parent
                    radius: StyleIsland.artRadius
                    color: StyleIsland.artScrim
                    opacity: artArea.containsMouse ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: StyleTokens.motionFeedbackDuration
                            easing.type: StyleTokens.easeFade
                        }
                    }

                    ThemedIcon {
                        anchors.centerIn: parent
                        size: StyleControl.iconSizeMd
                        source: IconRegistry.themeIcon("view-list-symbolic")
                        tint: Colors.base07
                    }
                }

                MouseArea {
                    id: artArea

                    anchors.fill: parent
                    enabled: root.canChoose
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pageRequested("sources")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: StyleTokens.space2

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.title.length > 0 ? root.title : "Not playing"
                    color: root.title.length > 0 ? Colors.base07 : Colors.base04
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeMd
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.artist.length > 0
                    elide: Text.ElideRight
                    text: root.artist
                    color: Colors.base04
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeMd
                }
            }

            // A full waveform beside the track, as the iPhone draws it, and gone
            // when paused rather than left as a row of dots.
            Widgets.CavaVisualizer {
                Layout.alignment: Qt.AlignVCenter
                barCount: StyleIsland.waveformBars
                barWidth: StyleIsland.waveformBarWidth
                barSpacing: StyleIsland.waveformBarSpacing
                barHeight: StyleIsland.waveformHeight
                enabled: root.active
                active: !!root.player && root.player.isPlaying
                barColor: Colors.base0D
                opacity: active ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: StyleTokens.motionFeedbackDuration
                        easing.type: StyleTokens.easeFade
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: StyleIsland.mediaScrubberGap
            spacing: StyleTokens.space8
            // Kept, dimmed, for a source with no timeline: hiding it made the
            // page's height depend on the player, so every source switch
            // resized the island under the dock.
            opacity: root.seekable && root.player.canSeek ? 1 : StyleTokens.opacityDisabled

            Text {
                text: root.seekable ? root.formatTime(root.position) : "--:--"
                color: Colors.base04
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeXs
                font.features: ({ "tnum": 1 })
            }

            Slider {
                Layout.fillWidth: true
                enabled: root.seekable && root.player.canSeek
                value: root.seekable ? root.position / root.length : 0
                onMoved: (fraction) => root.player.position = fraction * root.length
            }

            Text {
                text: root.seekable ? "-" + root.formatTime(root.length - root.position) : "--:--"
                color: Colors.base04
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeXs
                font.features: ({ "tnum": 1 })
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.topMargin: StyleIsland.mediaTransportGap
            Layout.preferredHeight: StyleIsland.transportHitSize

            Row {
                anchors.centerIn: parent
                spacing: StyleIsland.transportSpacing

                Button {
                    width: StyleIsland.transportHitSize
                    height: width
                    radius: height / 2
                    iconSource: IconRegistry.mediaIcon("skip-backward")
                    iconSize: StyleIsland.transportIconSize
                    foreground: Colors.base07
                    hoverBackground: StyleTokens.alphaActive
                    interactive: !!root.player && root.player.canGoPrevious
                    opacity: interactive ? 1 : StyleTokens.opacityDisabled
                    onClicked: Services.MediaPlayers.previous(root.player)
                }

                Button {
                    width: StyleIsland.transportHitSize
                    height: width
                    radius: height / 2
                    iconSource: IconRegistry.mediaIcon(root.player && root.player.isPlaying ? "pause" : "play")
                    iconSize: StyleIsland.transportPrimaryIconSize
                    foreground: Colors.base07
                    hoverBackground: StyleTokens.alphaActive
                    interactive: !!root.player && (root.player.isPlaying ? root.player.canPause : root.player.canPlay)
                    opacity: interactive ? 1 : StyleTokens.opacityDisabled
                    onClicked: Services.MediaPlayers.togglePlayback(root.player)
                }

                Button {
                    width: StyleIsland.transportHitSize
                    height: width
                    radius: height / 2
                    iconSource: IconRegistry.mediaIcon("skip-forward")
                    iconSize: StyleIsland.transportIconSize
                    foreground: Colors.base07
                    hoverBackground: StyleTokens.alphaActive
                    interactive: !!root.player && root.player.canGoNext
                    opacity: interactive ? 1 : StyleTokens.opacityDisabled
                    onClicked: Services.MediaPlayers.next(root.player)
                }
            }
        }
    }

}
