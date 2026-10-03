import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
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
    implicitHeight: column.implicitHeight + StyleIsland.fillInset + StyleIsland.pagePaddingBottom
    width: implicitWidth
    height: implicitHeight

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    ColumnLayout {
        id: column

        x: StyleIsland.fillInset
        y: StyleIsland.fillInset
        width: parent.width - StyleIsland.fillInset * 2
        spacing: StyleIsland.tileGridGap

        ClippingRectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: StyleIsland.heroHeight
            radius: StyleIsland.heroRadius
            color: StyleTokens.alphaLight

            // Uncached: theme.sh rewrites this one path, and the page is rebuilt
            // each time the island opens, so a fresh decode picks up a new
            // wallpaper without watching the file.
            Image {
                anchors.fill: parent
                source: StyleTokens.wallpaperPath
                sourceSize.width: StyleIsland.heroImageWidth
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: StyleIsland.heroScrimStart; color: StyleTokens.transparent }
                    GradientStop { position: 1; color: StyleIsland.heroScrim }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pageRequested("calendar")
            }

            Column {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: StyleIsland.heroPadding
                spacing: 0

                Text {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Colors.base07
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeDisplay
                    font.weight: Font.Light
                    font.letterSpacing: StyleIsland.clockLetterSpacing
                }

                Text {
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: Colors.base07
                    opacity: StyleIsland.heroDateOpacity
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeSm
                }
            }

            Column {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: StyleIsland.heroPadding
                visible: Services.WeatherState.hasData
                spacing: StyleTokens.space2

                Row {
                    anchors.right: parent.right
                    spacing: StyleTokens.space4

                    ThemedIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: StyleIsland.heroWeatherIconSize
                        source: IconRegistry.weatherIcon(Services.WeatherState.icon)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Services.WeatherState.temperature
                        color: Colors.base07
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeLg
                    }
                }

                Text {
                    anchors.right: parent.right
                    width: Math.min(implicitWidth, StyleIsland.pageWidth / 3)
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: Services.WeatherState.description
                    color: Colors.base07
                    opacity: StyleIsland.heroDateOpacity
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeSm
                }
            }

            MouseArea {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: parent.width / 2
                height: parent.height / 2
                visible: Services.WeatherState.hasData
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pageRequested("weather")
            }
        }

        LevelBar {
            label: "Volume"
            Layout.fillWidth: true
            enabled: Services.AudioState.hasSink
            value: Services.AudioState.sinkVolume
            muted: Services.AudioState.sinkMuted
            onMoved: (level) => Services.AudioState.setVolume(Services.AudioState.sink, level)
            onMuteRequested: Services.AudioState.toggleMute(Services.AudioState.sink)
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: StyleIsland.miniArtSize + StyleIsland.fillInset * 2
            visible: root.hasMedia
            radius: StyleTokens.radiusMd
            color: nowPlayingArea.containsMouse ? StyleTokens.alphaActive : StyleTokens.alphaLight

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
                anchors.margins: StyleIsland.fillInset
                spacing: StyleTokens.space12

                ArtImage {
                    Layout.preferredWidth: StyleIsland.miniArtSize
                    Layout.preferredHeight: StyleIsland.miniArtSize
                    radius: StyleTokens.radiusMd
                    source: Services.MediaPlayers.artUrl(root.player)
                    isIcon: Services.MediaPlayers.isSiteIcon(root.player)
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

                PillButton {
                    active: true
                    iconSource: IconRegistry.mediaIcon(root.player && root.player.isPlaying ? "pause" : "play")
                    interactive: Services.MediaPlayers.canTogglePlayback
                    onClicked: Services.MediaPlayers.togglePlayback()
                }
            }
        }
    }
}
