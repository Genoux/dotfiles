import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.config
import qs.services as Services

PanelWindow {
    id: root

    required property var screen

    readonly property var entries: Services.PowerMenu.entries

    readonly property int surfaceWidth: StylePowerMenu.padding * 2
        + entries.length * StylePowerMenu.itemWidth
        + Math.max(0, entries.length - 1) * StylePowerMenu.itemGap
    readonly property int surfaceHeight: StylePowerMenu.padding * 2 + StylePowerMenu.itemHeight

    readonly property bool active: Services.PowerMenu.visible && Services.PowerMenu.screen === root.screen

    property bool displayed: false

    screen: root.screen
    visible: displayed
    color: StyleTokens.transparent
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "power-menu"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onActiveChanged: {
        if (active) {
            surface.stopHide()
            displayed = true
            surface.show()
            Qt.callLater(() => focusScope.forceActiveFocus())
        } else {
            surface.hide()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: Services.PowerMenu.close()
    }

    OverlayPanel {
        id: surface

        width: root.surfaceWidth
        height: root.surfaceHeight
        anchors.centerIn: parent
        active: root.active
        onHideFinished: root.displayed = false

        FocusScope {
            id: focusScope

            anchors.fill: parent
            anchors.margins: StylePowerMenu.padding

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    Services.PowerMenu.close()
                    event.accepted = true
                    return
                }

                if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    actions.currentIndex = Math.min(actions.currentIndex + 1, Math.max(0, root.entries.length - 1))
                    event.accepted = true
                    return
                }

                if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    actions.currentIndex = Math.max(actions.currentIndex - 1, 0)
                    event.accepted = true
                    return
                }

                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.activate(root.entries[actions.currentIndex])
                    event.accepted = true
                }
            }

            ListView {
                id: actions

                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: StylePowerMenu.itemGap
                model: ScriptModel {
                    values: root.entries
                }
                currentIndex: 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: PowerMenuAction {
                    required property var modelData
                    required property int index

                    label: modelData.label
                    icon: modelData.icon
                    selected: ListView.isCurrentItem

                    onTriggered: root.activate(modelData)
                    onHovered: actions.currentIndex = index
                }
            }
        }
    }

    function activate(entry) {
        if (!entry)
            return

        Services.PowerMenu.close()

        if (entry.dispatch)
            Hyprland.dispatch(entry.dispatch)
        else if (entry.command)
            Quickshell.execDetached(entry.command)
    }
}
