import QtQuick
import qs.components
import qs.config
import qs.services

PopoverPanel {
    id: root

    signal dismiss()
    readonly property var recentEntries: ClipboardHistory.entries.slice(0, 15)
    property int selectedIndex: -1

    onSelectedIndexChanged: {
        if (selectedIndex >= 0)
            highlight.target = entries.itemAt(selectedIndex)
    }

    onActiveChanged: {
        if (active) {
            selectedIndex = -1
            highlight.target = null
            historyList.contentY = 0
            ClipboardHistory.refresh()
            Qt.callLater(() => root.forceActiveFocus())
        }
    }

    function moveSelection(delta) {
        if (!recentEntries.length)
            return
        selectedIndex = Math.max(0, Math.min(recentEntries.length - 1, selectedIndex + delta))
        const row = entries.itemAt(selectedIndex)
        if (row.y < historyList.contentY)
            historyList.contentY = row.y
        else if (row.y + row.height > historyList.contentY + historyList.height)
            historyList.contentY = row.y + row.height - historyList.height
    }

    Keys.onEscapePressed: dismiss()
    Keys.onDownPressed: moveSelection(1)
    Keys.onUpPressed: moveSelection(-1)
    Keys.onReturnPressed: ClipboardHistory.copy(recentEntries[Math.max(0, selectedIndex)])
    Keys.onEnterPressed: ClipboardHistory.copy(recentEntries[Math.max(0, selectedIndex)])

    Item {
        implicitWidth: StylePopover.panelWidth
        implicitHeight: content.implicitHeight
        width: implicitWidth
        height: implicitHeight

        Column {
            id: content
            width: parent.width
            spacing: 0

            PopoverHeader {
                width: parent.width
                title: "Clipboard"
            }

            PopoverSeparator {
                width: parent.width
            }

            Flickable {
                id: historyList
                width: parent.width
                height: Math.min(rows.implicitHeight, StylePopover.listMaxHeight)
                contentWidth: width
                contentHeight: rows.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                SlidingHighlight {
                    id: highlight
                    run: rows
                }

                Column {
                    id: rows
                    width: historyList.width
                    topPadding: StylePopover.contentPaddingV
                    bottomPadding: StylePopover.contentPaddingV
                    spacing: StylePopover.listRowSpacing

                    Repeater {
                        id: entries
                        model: root.recentEntries

                        PopoverAction {
                            id: entryRow
                            required property var modelData
                            required property int index

                            x: StylePopover.listRowInset
                            width: rows.width - x * 2
                            paddingH: StylePopover.contentPaddingH - StylePopover.listRowInset
                            label: modelData.filePath ? "Image" : modelData.value.replace(/\s+/g, " ").trim()
                            actionEnabled: root.active && !ClipboardHistory.busy
                            onActivated: ClipboardHistory.copy(modelData)
                            onHoveredChanged: {
                                if (hovered)
                                    root.selectedIndex = -1
                            }

                            Image {
                                anchors.right: parent.right
                                anchors.rightMargin: entryRow.paddingH
                                anchors.verticalCenter: parent.verticalCenter
                                width: StylePopover.rowHeight - StyleTokens.space8
                                height: width
                                visible: !!entryRow.modelData.filePath
                                source: visible ? "file://" + ClipboardHistory.resolvePath(entryRow.modelData.filePath) : ""
                                sourceSize.width: width * 2
                                sourceSize.height: height * 2
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                        }
                    }

                    PopoverMessage {
                        visible: root.recentEntries.length === 0
                        width: parent.width
                        height: StylePopover.emptyStateHeight
                        text: ClipboardHistory.error || "Nothing copied yet"
                    }
                }
            }

            PopoverMessage {
                visible: ClipboardHistory.error.length > 0 && root.recentEntries.length > 0
                width: parent.width
                text: ClipboardHistory.error
            }
        }
    }
}
