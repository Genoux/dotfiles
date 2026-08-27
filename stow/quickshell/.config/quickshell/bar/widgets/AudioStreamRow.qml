import QtQuick
import qs
import qs.components
import qs.config
import qs.services

// One application's playback stream: who is making the sound, and how loud it is
// on its own. The icon identifies the app faster than its name does, which
// matters in a list you open mid-playback to silence one thing.
Rectangle {
    id: row

    required property var node

    readonly property bool muted: AudioState.mutedOf(node)

    implicitHeight: StylePopover.streamRowHeight
    height: implicitHeight
    radius: StyleTokens.radiusSm
    color: StyleTokens.transparent

    ThemedIcon {
        id: appIcon

        anchors.left: parent.left
        anchors.leftMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
        anchors.verticalCenter: parent.verticalCenter
        size: StyleControl.iconSize
        source: IconRegistry.streamIcon(row.node?.properties)
        opacity: row.muted ? StyleTokens.opacityDisabled : 1
    }

    Text {
        id: name

        anchors.left: appIcon.right
        anchors.leftMargin: StyleTokens.space10
        anchors.right: muteButton.left
        anchors.rightMargin: StyleTokens.space6
        anchors.top: parent.top
        anchors.topMargin: StyleTokens.space2
        text: AudioState.streamLabel(row.node)
        color: row.muted ? Colors.base04 : Colors.base05
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeXs
        elide: Text.ElideRight
    }

    Button {
        id: muteButton

        anchors.right: parent.right
        anchors.rightMargin: StylePopover.contentPaddingH - StylePopover.listRowInset - StylePopover.ghostPaddingH
        anchors.verticalCenter: name.verticalCenter
        iconSource: IconRegistry.volumeIcon(AudioState.volumeOf(row.node), row.muted, true)
        iconSize: StyleControl.iconSizeSm
        paddingHorizontal: StylePopover.ghostPaddingH
        paddingVertical: StyleTokens.space2
        interactive: true
        onClicked: AudioState.toggleMute(row.node)
    }

    // Indented to the name rather than the row edge, so the icon column reads as
    // one gutter down the whole list.
    Slider {
        anchors.left: name.left
        anchors.right: parent.right
        anchors.rightMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
        anchors.bottom: parent.bottom
        anchors.bottomMargin: StyleTokens.space2
        value: AudioState.volumeOf(row.node)
        opacity: row.muted ? StyleTokens.opacityDisabled : 1
        onMoved: (level) => AudioState.setVolume(row.node, level)

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.easeDurationFast
                easing.type: StyleTokens.easeStandard
            }
        }
    }
}
