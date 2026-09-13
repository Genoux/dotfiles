import Quickshell
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
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

    onActiveChanged: {
        if (!active)
            results.cancelFlick()
    }

    function resetScroll() {
        results.cancelFlick()
        results.currentIndex = 0
        results.forceLayout()
        results.positionViewAtBeginning()
    }

    readonly property int listHeight: filteredEntries.length === 0
        ? StyleLauncher.emptyHeight
        : Math.min(
            filteredEntries.length * StyleLauncher.resultHeight + StyleLauncher.padding,
            StyleLauncher.listMaxHeight
        )

    // Typing breaks the declarative binding on `text`, so a reopen would keep
    // the previous query on screen while the service has already cleared it.
    function focusSearch() {
        searchInput.text = Services.Launcher.query
        searchInput.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: StyleLauncher.padding
        anchors.leftMargin: StyleLauncher.padding
        anchors.rightMargin: StyleLauncher.padding
        spacing: StyleLauncher.spacing

        Controls.TextField {
            id: searchInput

            Layout.fillWidth: true
            Layout.preferredHeight: StyleLauncher.searchHeight

            text: Services.Launcher.query
            placeholderText: "Search..."
            color: StyleLauncher.text
            placeholderTextColor: StyleLauncher.placeholder
            selectionColor: StyleLauncher.selection
            selectedTextColor: StyleLauncher.text
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeSm
            verticalAlignment: TextInput.AlignVCenter
            topPadding: 0
            bottomPadding: 0
            leftPadding: StyleTokens.space12 + StyleLauncher.searchIconSize + StyleTokens.space8
            rightPadding: StyleTokens.space12
            enabled: root.active
            Accessible.name: placeholderText

            background: Rectangle {
                radius: StyleTokens.radiusMd
                color: StyleLauncher.searchBg
                border.width: StyleTokens.borderWidth
                border.color: StyleOverlay.borderSubtle

                ThemedIcon {
                    x: StyleTokens.space12
                    anchors.verticalCenter: parent.verticalCenter
                    source: Quickshell.iconPath("system-search-symbolic")
                    size: StyleLauncher.searchIconSize
                    tint: StyleLauncher.text
                }
            }

            onTextChanged: {
                if (Services.Launcher.query !== text)
                    Services.Launcher.query = text
                results.currentIndex = 0
            }

            onAccepted: root.launch(root.filteredEntries[results.currentIndex])

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
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.listHeight

            ListView {
                id: results

                anchors.fill: parent
                model: ScriptModel {
                    values: root.filteredEntries
                }
                currentIndex: 0
                spacing: 0
                clip: true
                // Every delegate build resolves an icon off disk, so churning
                // them on each keystroke is the expensive part of retyping.
                reuseItems: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: root.active

                highlight: Rectangle {
                    radius: StyleTokens.radiusMd
                    color: StyleLauncher.selectedBg
                    border.width: StyleTokens.borderWidth
                    border.color: StyleOverlay.borderSubtle
                }
                // ListView paces the highlight by velocity unless duration wins.
                highlightMoveVelocity: -1
                highlightMoveDuration: StyleTokens.motionFeedbackDuration
                highlightResizeDuration: 0

                footer: Item {
                    width: results.width
                    height: StyleLauncher.padding
                }

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: results.width
                    height: StyleLauncher.resultHeight

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: StyleTokens.space8
                        anchors.rightMargin: StyleTokens.space8
                        spacing: StyleTokens.space10

                        ThemedIcon {
                            Layout.alignment: Qt.AlignVCenter
                            source: Quickshell.iconPath(modelData.icon || "application-x-executable")
                            size: StyleLauncher.iconSize
                            colored: true
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
                        enabled: root.active
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // The list scrolls under a stationary cursor during
                        // arrow-key nav; entered() would drag the selection
                        // back to whatever row slid beneath it.
                        onPositionChanged: results.currentIndex = index
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
}
