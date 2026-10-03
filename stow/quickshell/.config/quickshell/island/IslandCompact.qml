import QtQuick
import Quickshell
import qs
import qs.bar.widgets as Widgets
import qs.components
import qs.config
import qs.services as Services

Item {
    id: root

    readonly property var player: Services.MediaPlayers.player
    readonly property bool hasMedia: !!player && Services.MediaPlayers.hasTrackMetadata(player)
    // Both flanks share a width so the time stays centred in the pill.
    readonly property int slotWidth: hasMedia ? Math.max(StyleIsland.activityArtSize, StyleCava.visualWidth) : 0

    implicitWidth: StyleIsland.compactPaddingH * 2
        + clockMeasure.width
        + (slotWidth > 0 ? (slotWidth + StyleIsland.compactSpacing) * 2 : 0)
    implicitHeight: StyleIsland.compactHeight

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Digits are not the same width, so measuring the live text would nudge the
    // whole pill every minute.
    TextMetrics {
        id: clockMeasure

        text: "88:88"
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeMd
        font.weight: Font.Medium
    }

    Text {
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Colors.base05
        font: clockMeasure.font
    }

    Item {
        anchors.left: parent.left
        anchors.leftMargin: StyleIsland.compactPaddingH
        anchors.verticalCenter: parent.verticalCenter
        width: root.slotWidth
        height: parent.height
        opacity: root.hasMedia ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeFade
            }
        }

        ArtImage {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: StyleIsland.activityArtSize
            height: width
            radius: StyleIsland.activityArtRadius
            source: Services.MediaPlayers.artUrl(root.player)
                isIcon: Services.MediaPlayers.isSiteIcon(root.player)
        }
    }

    Item {
        anchors.right: parent.right
        anchors.rightMargin: StyleIsland.compactPaddingH
        anchors.verticalCenter: parent.verticalCenter
        width: root.slotWidth
        height: parent.height
        opacity: root.hasMedia ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeFade
            }
        }

        Widgets.CavaVisualizer {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            active: root.player ? root.player.isPlaying : false
        }
    }
}
