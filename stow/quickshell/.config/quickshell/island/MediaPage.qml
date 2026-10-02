import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.bar.widgets as Widgets
import qs.components
import qs.config
import qs.services as Services

Item {
    id: root

    property bool active: false
    property bool choosingPlayer: false

    readonly property var players: Services.MediaPlayers.activePlayers
    readonly property var player: Services.MediaPlayers.player
    readonly property string title: player ? Services.MediaPlayers.cleanField(player.trackTitle) : ""
    readonly property string artist: player ? Services.MediaPlayers.cleanField(player.trackArtist) : ""
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real position: player && player.positionSupported ? player.position : 0
    readonly property bool seekable: length > 0 && !Services.MediaPlayers.isLiveStream(player)
    readonly property bool canChoose: players.length > 1

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

    onCanChooseChanged: {
        if (!canChoose)
            choosingPlayer = false;
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
        spacing: StyleIsland.pageSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: StyleTokens.space12

            ArtImage {
                Layout.preferredWidth: StyleIsland.artSize
                Layout.preferredHeight: StyleIsland.artSize
                radius: StyleIsland.artRadius
                source: Services.MediaPlayers.artUrl(root.player)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: StyleTokens.space2

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.title.length > 0 ? root.title : "Nothing playing"
                    color: root.title.length > 0 ? Colors.base06 : Colors.base04
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeLg
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

                // Where the sound comes from, as plain words under the track. With
                // several players it is also the way to change source.
                Item {
                    Layout.preferredWidth: sourceRow.implicitWidth
                    Layout.preferredHeight: sourceRow.implicitHeight
                    Layout.topMargin: StyleTokens.space2
                    visible: !!root.player

                    RowLayout {
                        id: sourceRow

                        spacing: StyleTokens.space2

                        Text {
                            text: root.player ? root.player.identity : ""
                            color: sourceArea.containsMouse ? Colors.base05 : Colors.base04
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeXs

                            Behavior on color {
                                ColorAnimation {
                                    duration: StyleTokens.motionFeedbackDuration
                                    easing.type: StyleTokens.easeFade
                                }
                            }
                        }

                        ThemedIcon {
                            visible: root.canChoose
                            source: IconRegistry.shellIcon(root.choosingPlayer ? "go-up-symbolic" : "go-down-symbolic")
                            size: StyleIsland.sourceChevronSize
                            tint: Colors.base04
                        }
                    }

                    MouseArea {
                        id: sourceArea

                        anchors.fill: parent
                        anchors.margins: -StyleTokens.space4
                        enabled: root.canChoose
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.choosingPlayer = !root.choosingPlayer
                    }
                }
            }

            Widgets.CavaVisualizer {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: StyleTokens.space4
                enabled: root.active
                active: !!root.player && root.player.isPlaying
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: StyleTokens.space8
            visible: root.seekable
            opacity: root.player && root.player.canSeek ? 1 : StyleTokens.opacityDisabled

            Text {
                text: root.formatTime(root.position)
                color: Colors.base04
                font.family: StyleTokens.fontMono
                font.pixelSize: StyleTokens.fontSizeXs
            }

            Slider {
                Layout.fillWidth: true
                enabled: !!root.player && root.player.canSeek
                value: root.length > 0 ? root.position / root.length : 0
                onMoved: (fraction) => root.player.position = fraction * root.length
            }

            Text {
                text: "-" + root.formatTime(root.length - root.position)
                color: Colors.base04
                font.family: StyleTokens.fontMono
                font.pixelSize: StyleTokens.fontSizeXs
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: transport.implicitWidth
            implicitHeight: transport.implicitHeight

            // Plain glyphs on no box: the travelling fill is the only hover
            // feedback, as on the bar's own media controls.
            SlidingHighlight {
                run: transport
            }

            Row {
                id: transport

                spacing: StyleTokens.space20

                Button {
                    iconSource: IconRegistry.mediaIcon("skip-backward")
                    iconSize: StyleIsland.transportIconSize
                    hoverBackground: StyleTokens.transparent
                    interactive: !!root.player && root.player.canGoPrevious
                    opacity: interactive ? 1 : StyleTokens.opacityDisabled
                    onClicked: Services.MediaPlayers.previous(root.player)
                }

                Button {
                    iconSource: IconRegistry.mediaIcon(root.player && root.player.isPlaying ? "pause" : "play")
                    iconSize: StyleIsland.transportIconSize
                    hoverBackground: StyleTokens.transparent
                    interactive: !!root.player && (root.player.isPlaying ? root.player.canPause : root.player.canPlay)
                    opacity: interactive ? 1 : StyleTokens.opacityDisabled
                    onClicked: Services.MediaPlayers.togglePlayback(root.player)
                }

                Button {
                    iconSource: IconRegistry.mediaIcon("skip-forward")
                    iconSize: StyleIsland.transportIconSize
                    hoverBackground: StyleTokens.transparent
                    interactive: !!root.player && root.player.canGoNext
                    opacity: interactive ? 1 : StyleTokens.opacityDisabled
                    onClicked: Services.MediaPlayers.next(root.player)
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: playerList.implicitHeight
            visible: root.choosingPlayer

            SlidingHighlight {
                run: playerList
            }

            Column {
                id: playerList

                width: parent.width

                Repeater {
                    model: ScriptModel {
                        values: root.players
                    }

                    Item {
                        id: playerRow

                        required property var modelData

                        readonly property bool current: modelData === root.player
                        readonly property bool hovered: rowArea.containsMouse

                        width: playerList.width
                        height: StylePopover.rowHeight

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: StyleTokens.space8
                            anchors.rightMargin: StyleTokens.space8
                            spacing: StyleTokens.space8

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: playerRow.modelData.identity
                                color: playerRow.current ? Colors.base05 : Colors.base04
                                font.family: StyleTokens.fontSans
                                font.pixelSize: StyleTokens.fontSizeSm
                                font.weight: playerRow.current ? Font.DemiBold : Font.Normal
                            }

                            Text {
                                visible: playerRow.modelData.isPlaying
                                text: "Playing"
                                color: Colors.base04
                                font.family: StyleTokens.fontSans
                                font.pixelSize: StyleTokens.fontSizeXs
                            }
                        }

                        MouseArea {
                            id: rowArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Services.MediaPlayers.selectPlayer(playerRow.modelData);
                                root.choosingPlayer = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
