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
        anchors.topMargin: StyleLauncher.padding
        anchors.leftMargin: StyleLauncher.padding
        anchors.rightMargin: StyleLauncher.padding
        spacing: StyleLauncher.spacing

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: StyleLauncher.searchHeight
            radius: StyleTokens.radiusMd
            color: StyleLauncher.searchBg
            border.width: 1
            border.color: StyleOverlay.borderSubtle

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
                        color: StyleLauncher.text
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
                        color: StyleLauncher.text
                        selectionColor: StyleLauncher.selection
                        selectedTextColor: StyleLauncher.text
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeSm
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
                        color: StyleLauncher.placeholder
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeSm
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
                    height: StyleLauncher.padding
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    readonly property bool selected: ListView.isCurrentItem

                    width: results.width
                    height: StyleLauncher.resultHeight
                    radius: StyleTokens.radiusMd
                    color: selected ? StyleLauncher.selectedBg : StyleTokens.transparent
                    border.width: selected ? 1 : 0
                    border.color: StyleOverlay.borderSubtle

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        IconImage {
                            Layout.alignment: Qt.AlignVCenter
                            width: StyleLauncher.iconSize
                            height: StyleLauncher.iconSize
                            implicitSize: StyleLauncher.iconSize
                            source: Quickshell.iconPath(modelData.icon || "application-x-executable")
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.name
                            color: StyleLauncher.text
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeSm
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
                color: StyleLauncher.placeholder
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
            }
        }
    }

    readonly property int listHeight: filteredEntries.length === 0
        ? StyleLauncher.emptyHeight
        : Math.min(
            filteredEntries.length * StyleLauncher.resultHeight + StyleLauncher.padding,
            StyleLauncher.listMaxHeight
        )

    function focusSearch() {
        searchInput.forceActiveFocus()
    }
}
