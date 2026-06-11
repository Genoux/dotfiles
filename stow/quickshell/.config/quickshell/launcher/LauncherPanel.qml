import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.components
import qs.config
import qs.services as Services

Item {
    id: root

    required property var filteredEntries
    required property bool active

    signal launch(var entry)
    signal close

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Style.launcherPadding
        anchors.leftMargin: Style.launcherPadding
        anchors.rightMargin: Style.launcherPadding
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
                                root.close()
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
                        z: -1
                        visible: searchInput.text.length === 0
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
            Layout.preferredHeight: root.listHeight
            clip: true

            ListView {
                id: results

                anchors.fill: parent
                model: ScriptModel {
                    values: root.filteredEntries
                }
                currentIndex: 0
                spacing: 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                footer: Item {
                    width: results.width
                    height: Style.launcherPadding
                }

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
                visible: root.filteredEntries.length === 0
                text: "No Results"
                color: Style.launcherPlaceholder
                font.family: Style.fontSans
                font.pixelSize: Style.fontSizeSm
            }
        }
    }

    readonly property int listHeight: filteredEntries.length === 0
        ? Style.launcherEmptyHeight
        : Math.min(
            filteredEntries.length * Style.launcherResultHeight + Style.launcherPadding,
            Style.launcherListMaxHeight
        )

    function focusSearch() {
        searchInput.forceActiveFocus()
    }
}
