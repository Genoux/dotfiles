import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.config
import qs.services as Services

Item {
    id: root

    readonly property var player: Services.MediaPlayers.player
    readonly property bool hasMedia: Services.MediaPlayers.hasTrackMetadata(player)

    signal pageRequested(string pageId)

    implicitWidth: StyleIsland.pageWidth
    implicitHeight: column.implicitHeight + StyleIsland.pagePaddingTop + StyleIsland.pagePaddingBottom
    width: implicitWidth
    height: implicitHeight

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    ColumnLayout {
        id: column

        x: StyleIsland.pagePaddingH
        y: StyleIsland.pagePaddingTop
        width: parent.width - StyleIsland.pagePaddingH * 2
        spacing: StyleIsland.pageSpacing

        RowLayout {
            Layout.fillWidth: true

            Column {
                spacing: StyleTokens.space2

                Text {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Colors.base05
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleIsland.clockSize
                    font.weight: Font.DemiBold
                }

                Text {
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: Colors.base04
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeSm
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ColumnLayout {
                visible: Services.WeatherState.hasData
                spacing: StyleTokens.space2

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: StyleTokens.space4

                    ThemedIcon {
                        source: IconRegistry.weatherIcon(Services.WeatherState.icon)
                    }

                    Text {
                        text: Services.WeatherState.temperature
                        color: Colors.base05
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeMd
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignRight
                    Layout.maximumWidth: StyleIsland.pageWidth / 3
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: Services.WeatherState.description
                    color: Colors.base04
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeXs
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: StyleTokens.space8

            Button {
                iconSource: IconRegistry.volumeIcon(Services.AudioState.sinkVolume, Services.AudioState.sinkMuted, Services.AudioState.hasSink)
                interactive: Services.AudioState.hasSink
                onClicked: Services.AudioState.toggleMute(Services.AudioState.sink)
            }

            Slider {
                Layout.fillWidth: true
                enabled: Services.AudioState.hasSink
                value: Services.AudioState.sinkVolume
                onMoved: (level) => Services.AudioState.setVolume(Services.AudioState.sink, level)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: StyleIsland.miniArtSize + StyleTokens.space8 * 2
            visible: root.hasMedia
            radius: StyleTokens.radiusSm
            color: nowPlayingArea.containsMouse ? StyleTokens.alphaLight : StyleTokens.transparent

            Behavior on color {
                ColorAnimation {
                    duration: StyleTokens.motionFeedbackDuration
                    easing.type: StyleTokens.easeFade
                }
            }

            MouseArea {
                id: nowPlayingArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pageRequested("media")
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: StyleTokens.space8
                spacing: StyleTokens.space12

                ArtImage {
                    Layout.preferredWidth: StyleIsland.miniArtSize
                    Layout.preferredHeight: StyleIsland.miniArtSize
                    radius: StyleTokens.radiusXs
                    source: Services.MediaPlayers.artUrl(root.player)
                }

                Column {
                    Layout.fillWidth: true
                    spacing: StyleTokens.space2

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.player ? root.player.trackTitle : ""
                        color: Colors.base05
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeSm
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        visible: text.length > 0
                        elide: Text.ElideRight
                        text: root.player ? Services.MediaPlayers.cleanField(root.player.trackArtist) : ""
                        color: Colors.base04
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeXs
                    }
                }

                Button {
                    iconSource: IconRegistry.mediaIcon(root.player && root.player.isPlaying ? "pause" : "play")
                    interactive: Services.MediaPlayers.canTogglePlayback
                    onClicked: Services.MediaPlayers.togglePlayback()
                }
            }
        }
    }
}
