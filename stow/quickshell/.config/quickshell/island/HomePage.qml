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

    property bool heroActionsShown: false
    property bool swappingWallpaper: false

    signal pageRequested(string pageId)
    signal collapseRequested()

    implicitWidth: StyleIsland.pageWidth
    implicitHeight: column.implicitHeight + StyleIsland.fillInset + StyleIsland.pagePaddingBottom
    width: implicitWidth
    height: implicitHeight

    Timer {
        id: swapTimeout

        interval: StyleIsland.wallpaperSwapTimeout
        onTriggered: root.swappingWallpaper = false
    }

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

        WallpaperCard {
            Layout.fillWidth: true
            Layout.preferredHeight: StyleIsland.heroHeight
            onRefreshed: root.swappingWallpaper = false

            HoverHandler {
                id: heroHover

                onHoveredChanged: {
                    if (hovered) {
                        heroReveal.restart();
                    } else {
                        heroReveal.stop();
                        root.heroActionsShown = false;
                    }
                }
            }

            Timer {
                id: heroReveal

                interval: StyleTokens.motionHoverDelay
                onTriggered: root.heroActionsShown = true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pageRequested("calendar")
            }

            // Runs detached through Hyprland, like the keybind: a child of this
            // page would die with it when the island closed, part way between
            // swapping the image and regenerating the theme.
            Button {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: StyleIsland.heroActionInset
                radius: StyleIsland.heroActionRadius
                iconSource: IconRegistry.shellIcon("wallpaper")
                foreground: Colors.base07
                background: StyleIsland.heroActionFill
                hoverBackground: StyleIsland.heroActionHoverFill
                interactive: true
                opacity: root.heroActionsShown ? (root.swappingWallpaper ? StyleTokens.opacityDisabled : 1) : 0
                visible: opacity > 0
                // Ignored rather than disabled while a swap runs: a disabled
                // button lets the click through to the hero, which opens the
                // calendar.
                onClicked: {
                    if (root.swappingWallpaper)
                        return;

                    root.swappingWallpaper = true;
                    swapTimeout.restart();
                    ShellActions.runLocalScript("system-pick-wallpaper");
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: StyleTokens.motionFeedbackDuration
                        easing.type: StyleTokens.easeFade
                    }
                }
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
            color: cardHover.hovered ? StyleTokens.alphaActive : StyleTokens.alphaLight

            Behavior on color {
                ColorAnimation {
                    duration: StyleTokens.motionFeedbackDuration
                    easing.type: StyleTokens.easeFade
                }
            }

            // Passive, so the card stays lit while the pointer is on its
            // transport buttons, which take the click area's own hover.
            HoverHandler {
                id: cardHover
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Services.MediaPlayers.focusSource(root.player);
                    root.collapseRequested();
                }
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

                HoverRow {
                    spacing: StyleTokens.space2

                    Button {
                        iconSource: IconRegistry.mediaIcon("skip-backward")
                        iconSize: StyleIsland.miniTransportIconSize
                        interactive: Services.MediaPlayers.canGoPrevious
                        opacity: interactive ? 1 : StyleTokens.opacityDisabled
                        onClicked: Services.MediaPlayers.previous()
                    }

                    Button {
                        iconSource: IconRegistry.mediaIcon(root.player && root.player.isPlaying ? "pause" : "play")
                        iconSize: StyleIsland.miniTransportIconSize
                        interactive: Services.MediaPlayers.canTogglePlayback
                        opacity: interactive ? 1 : StyleTokens.opacityDisabled
                        onClicked: Services.MediaPlayers.togglePlayback()
                    }

                    Button {
                        iconSource: IconRegistry.mediaIcon("skip-forward")
                        iconSize: StyleIsland.miniTransportIconSize
                        interactive: Services.MediaPlayers.canGoNext
                        opacity: interactive ? 1 : StyleTokens.opacityDisabled
                        onClicked: Services.MediaPlayers.next()
                    }
                }
            }
        }
    }
}
