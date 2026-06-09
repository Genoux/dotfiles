import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.components
import qs.config
import qs.services as Services

PanelWindow {
    id: root

    required property var screen

    readonly property string normalizedQuery: Services.Launcher.query.toLowerCase().trim()
    readonly property var filteredEntries: {
        const _ = Services.LauncherHistory.revision
        if (normalizedQuery.length === 0)
            return Services.LauncherHistory.recentEntries()

        return Services.LauncherHistory.sortEntries(
            DesktopEntries.applications.values.filter((entry) => matches(entry))
        ).slice(0, Style.launcherMaxResults)
    }
    readonly property int listHeight: filteredEntries.length === 0
        ? Style.launcherEmptyHeight
        : Math.min(
            filteredEntries.length * Style.launcherResultHeight,
            Style.launcherListMaxHeight
        )
    readonly property int surfaceHeight: Style.launcherPadding * 2
        + Style.launcherSearchHeight
        + Style.launcherSpacing
        + listHeight

    readonly property bool active: Services.Launcher.visible && Services.Launcher.screen === root.screen

    property bool displayed: false
    property var closingEntries: []
    property int closingListHeight: listHeight
    property int closingSurfaceHeight: surfaceHeight

    readonly property var visibleEntries: root.active ? root.filteredEntries : root.closingEntries
    readonly property int visibleListHeight: root.active ? root.listHeight : root.closingListHeight

    OverlayRevealController {
        id: reveal

        active: root.active
        onHideFinished: root.finishHide()
    }

    screen: root.screen
    visible: displayed
    color: Style.transparent
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "launcher"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function snapshotClosingLayout() {
        closingEntries = filteredEntries
        closingListHeight = listHeight
        closingSurfaceHeight = surfaceHeight
    }

    function finishHide() {
        displayed = false
        Services.Launcher.finalizeClose()
    }

    onActiveChanged: {
        if (active) {
            reveal.stopHide()
            displayed = true
            reveal.show()
            Qt.callLater(() => searchInput.forceActiveFocus())
        } else {
            snapshotClosingLayout()
            reveal.hide()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: Services.Launcher.close()
    }

    Item {
        id: surfaceHost

        width: Style.launcherWidth
        height: root.active ? root.surfaceHeight : root.closingSurfaceHeight
        anchors.centerIn: parent
        scale: reveal.revealScale
        transformOrigin: Item.Center

        Behavior on height {
            NumberAnimation {
                duration: Style.overlayShowDuration
                easing.type: Easing.OutCubic
            }
        }

        OverlayDialogSurface {
            anchors.fill: parent
            revealOpacity: reveal.revealOpacity

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.launcherPadding
                spacing: Style.launcherSpacing

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.launcherSearchHeight
                radius: Style.radiusMd
                color: Style.launcherSearchBg
                border.width: 1
                border.color: Style.overlayBorderSubtle

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16

                        IconImage {
                            id: searchIconSource

                            anchors.fill: parent
                            source: Quickshell.iconPath("system-search-symbolic")
                            visible: false
                        }

                        ColorOverlay {
                            anchors.fill: parent
                            source: searchIconSource
                            color: Style.launcherText
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: parent.height

                        TextInput {
                            id: searchInput

                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            text: Services.Launcher.query
                            color: Style.launcherText
                            selectionColor: Style.launcherSelection
                            selectedTextColor: Style.launcherText
                            font.family: Style.fontSans
                            font.pixelSize: Style.fontSizeSm
                            font.weight: Font.Normal
                            clip: true
                            enabled: root.active
                            cursorVisible: root.active && activeFocus
                            onTextChanged: {
                                if (Services.Launcher.query !== text)
                                    Services.Launcher.query = text
                                results.currentIndex = 0
                            }

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Escape) {
                                    Services.Launcher.close()
                                    event.accepted = true
                                    return
                                }

                                if (event.key === Qt.Key_Down) {
                                    results.currentIndex = Math.min(results.currentIndex + 1, Math.max(0, root.filteredEntries.length - 1))
                                    event.accepted = true
                                    return
                                }

                                if (event.key === Qt.Key_Up) {
                                    results.currentIndex = Math.max(results.currentIndex - 1, 0)
                                    event.accepted = true
                                    return
                                }

                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.launch(root.filteredEntries[results.currentIndex])
                                    event.accepted = true
                                }
                            }
                        }

                        Text {
                            anchors.fill: parent
                            visible: searchInput.text.length === 0 && !searchInput.activeFocus
                            text: "Search..."
                            color: Style.launcherPlaceholder
                            font.family: Style.fontSans
                            font.pixelSize: Style.fontSizeSm
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.visibleListHeight
                clip: true

                ListView {
                    id: results

                    anchors.fill: parent
                    model: ScriptModel {
                        values: root.visibleEntries
                    }
                    currentIndex: 0
                    spacing: 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        readonly property bool selected: ListView.isCurrentItem

                        width: results.width
                        height: Style.launcherResultHeight
                        radius: Style.radiusMd
                        color: selected ? Style.launcherSelectedBg : Style.transparent
                        border.width: selected ? 1 : 0
                        border.color: Style.overlayBorderSubtle

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            IconImage {
                                Layout.alignment: Qt.AlignVCenter
                                width: Style.launcherIconSize
                                height: Style.launcherIconSize
                                implicitSize: Style.launcherIconSize
                                source: Quickshell.iconPath(modelData.icon || "application-x-executable")
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.name
                                color: Style.launcherText
                                font.family: Style.fontSans
                                font.pixelSize: Style.fontSizeSm
                                font.weight: Font.Normal
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: results.currentIndex = index
                            onClicked: root.launch(modelData)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.visibleEntries.length === 0
                    text: "No Results"
                    color: Style.launcherPlaceholder
                    font.family: Style.fontSans
                    font.pixelSize: Style.fontSizeSm
                }
            }
        }
        }
    }

    function matches(entry) {
        if (normalizedQuery.length === 0)
            return false

        const haystack = [
            entry.name,
            entry.genericName,
            entry.comment,
            entry.id,
            ...(entry.keywords ?? []),
            ...(entry.categories ?? []),
        ].join(" ").toLowerCase()

        const terms = normalizedQuery.split(/\s+/).filter((term) => term.length > 0)
        return terms.every((term) => haystack.includes(term))
    }

    function launch(entry) {
        if (!entry)
            return

        Services.LauncherHistory.record(entry)
        entry.execute()
        Services.Launcher.close()
    }
}
