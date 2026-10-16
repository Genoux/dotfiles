import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.config
import qs.services as Services

Item {
    id: root

    signal pageRequested(string requestedPage)

    implicitWidth: StyleIsland.pageWidth
    implicitHeight: rows.implicitHeight + StyleIsland.fillInset + StyleIsland.pagePaddingBottom
    width: implicitWidth
    height: implicitHeight

    Column {
        id: rows

        x: StyleIsland.fillInset
        y: StyleIsland.fillInset
        width: parent.width - StyleIsland.fillInset * 2
        spacing: StyleIsland.sourceRowSpacing

        Repeater {
            model: Services.MediaPlayers.activePlayers

            Rectangle {
                id: sourceRow

                required property var modelData
                readonly property string trackTitle: Services.MediaPlayers.cleanField(modelData.trackTitle)

                width: rows.width
                height: StyleIsland.sourceRowHeight
                radius: StyleTokens.radiusMd
                color: rowArea.containsMouse ? StyleTokens.alphaActive : modelData === Services.MediaPlayers.player ? StyleTokens.alphaLight : StyleTokens.transparent

                Behavior on color {
                    ColorAnimation {
                        duration: StyleTokens.motionFeedbackDuration
                        easing.type: StyleTokens.easeFade
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: StyleIsland.fillInset
                    spacing: StyleTokens.space12

                    ArtImage {
                        Layout.preferredWidth: StyleIsland.sourceArtSize
                        Layout.preferredHeight: StyleIsland.sourceArtSize
                        radius: StyleTokens.radiusSm
                        source: Services.MediaPlayers.artUrl(sourceRow.modelData)
                        isIcon: Services.MediaPlayers.isSiteIcon(sourceRow.modelData)
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: StyleTokens.space2

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: sourceRow.trackTitle.length > 0 ? sourceRow.trackTitle : sourceRow.modelData.identity
                            color: Colors.base05
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeSm
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            visible: text.length > 0
                            elide: Text.ElideRight
                            text: Services.MediaPlayers.cleanField(sourceRow.modelData.trackArtist)
                            color: Colors.base04
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeXs
                        }
                    }

                    ThemedIcon {
                        size: StyleControl.iconSizeMd
                        source: IconRegistry.playerIcon(sourceRow.modelData)
                        colored: true
                    }
                }

                MouseArea {
                    id: rowArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Services.MediaPlayers.selectPlayer(sourceRow.modelData);
                        root.pageRequested("media");
                    }
                }
            }
        }
    }
}
