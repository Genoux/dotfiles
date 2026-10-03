import QtQuick
import qs
import qs.components
import qs.config
import qs.services as Services

// The island's page switcher: one icon per page, a selected chip that fades in
// on the current page and a hover fill that follows the pointer. The chip does
// not travel: a page change is a choice, not a movement along the row. Used by
// the expanded island's footer and by the wide bar, which is why it owns
// neither a track nor a size.
Item {
    id: root

    property var tabs: []
    property string currentTab: ""
    property int tabSize: StyleIsland.footerTabSize
    property int tabRadius: StyleIsland.footerTabRadius
    property int spacing: StyleIsland.footerTrackPadding

    signal tabSelected(string tab)

    implicitWidth: tabRow.implicitWidth
    implicitHeight: tabSize

    function iconFor(id) {
        switch (id) {
        case "home":
            return IconRegistry.themeIcon("user-home-symbolic");
        case "launcher":
            return IconRegistry.barControlIcon("launcher");
        case "media":
            return IconRegistry.themeIcon("audio-x-generic-symbolic");
        case "sound":
            return IconRegistry.volumeIcon(Services.AudioState.sinkVolume, Services.AudioState.sinkMuted, Services.AudioState.hasSink);
        case "network":
            return IconRegistry.networkIcon(Services.Network.iconKey);
        case "bluetooth":
            return IconRegistry.bluetoothIcon(true);
        case "clipboard":
            return IconRegistry.themeIcon("edit-paste-symbolic");
        case "more":
            return IconRegistry.themeIcon("view-more-symbolic");
        default:
            return "";
        }
    }

    SlidingHighlight {
        run: tabRow
        radius: root.tabRadius
    }

    Row {
        id: tabRow

        spacing: root.spacing

        Repeater {
            model: root.tabs

            Item {
                id: tab

                required property string modelData

                readonly property bool selected: modelData === root.currentTab
                // The selected tab carries its own fill, so it is not a
                // peer of the travelling hover fill.
                readonly property bool hovered: !selected && icon.hovered

                width: root.tabSize
                height: root.tabSize

                Rectangle {
                    anchors.fill: parent
                    radius: root.tabRadius
                    color: StyleControl.chipFill
                    opacity: tab.selected ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: StyleTokens.motionFeedbackDuration
                            easing.type: StyleTokens.easeFade
                        }
                    }
                }

                Button {
                    id: icon

                    anchors.fill: parent
                    iconSource: root.iconFor(tab.modelData)
                    foreground: tab.selected ? StyleControl.chipContent : Colors.base04
                    hoverBackground: StyleTokens.transparent
                    minimumWidth: 0
                    minimumHeight: 0
                    interactive: true
                    Accessible.name: tab.modelData
                    onClicked: root.tabSelected(tab.modelData)

                    // In step with the chip, or the glyph turns light while the
                    // chip under it is still white and vanishes for a frame.
                    Behavior on foreground {
                        ColorAnimation {
                            duration: StyleTokens.motionFeedbackDuration
                            easing.type: StyleTokens.easeFade
                        }
                    }
                }
            }
        }
    }
}
