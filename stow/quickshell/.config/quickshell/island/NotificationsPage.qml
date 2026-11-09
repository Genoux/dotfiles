import QtQuick
import Quickshell
import qs
import qs.components
import qs.config
import qs.notifications
import qs.services as Services

// The island's notification center: the update card, then everything that
// arrived, by day, one stack per app. Leaving the page is what marks it all
// seen, so the dots stay on what was new for as long as you are looking at it.
PopoverPanel {
    id: root

    flushBottom: true
    underFooter: true

    signal collapseRequested()

    readonly property var systemUpdate: Services.NotificationCenter.systemUpdate
    readonly property var feed: Services.NotificationCenter.feed
    readonly property bool empty: feed.length === 0 && systemUpdate === null
    // Re-evaluated every minute but only changes at midnight, so the sections
    // are rebuilt by a new notification, never by the clock.
    readonly property string todayKey: dayKey(clock.date.getTime())
    readonly property string yesterdayKey: {
        const yesterday = new Date(`${todayKey}T00:00:00`)
        yesterday.setDate(yesterday.getDate() - 1)
        return dayKey(yesterday.getTime())
    }
    readonly property var sections: ["Today", "Yesterday", "Earlier"]
        .map((label) => ({ "label": label, "stacks": stacksByApp(label, feed.filter((entry) => sectionOf(entry.time) === label)) }))
        .filter((section) => section.stacks.length > 0)
    // Open stacks only last while the page is up; it is rebuilt on every visit.
    property var expandedStacks: []

    function dayKey(time) {
        return Qt.formatDate(new Date(time), "yyyy-MM-dd")
    }

    function sectionOf(time) {
        const key = dayKey(time)
        return key === todayKey ? "Today" : key === yesterdayKey ? "Yesterday" : "Earlier"
    }

    function appKey(entry) {
        return entry.desktopEntry || entry.appName || entry.appIcon
    }

    // In order of first appearance, and the feed is newest first: the stack
    // holding the newest notification leads, and every stack opens on its own
    // newest.
    function stacksByApp(label, entries) {
        return Array.from(new Set(entries.map(appKey))).map((key) => {
            const stackEntries = entries.filter((entry) => appKey(entry) === key)
            return {
                "key": `${label}:${key}`,
                "appName": stackEntries[0].appName,
                "entries": stackEntries
            }
        })
    }

    function setExpanded(stackKey, expanded) {
        const others = expandedStacks.filter((key) => key !== stackKey)
        expandedStacks = expanded ? [...others, stackKey] : others
    }

    // The clock only drives re-evaluation: its date is floored to the minute,
    // which made every age up to a minute short.
    function timeLabel(time) {
        const minutes = Math.floor((Math.max(clock.date.getTime(), Date.now()) - time) / 60000)
        if (minutes < 1)
            return "now"
        if (minutes < 60)
            return `${minutes}m`
        if (sectionOf(time) === "Earlier")
            return Qt.formatDate(new Date(time), "d MMM")
        return Qt.formatTime(new Date(time), "HH:mm")
    }

    onActiveChanged: {
        if (!active)
            Services.NotificationCenter.markAllSeen()
    }

    component RowText: Column {
        id: rowText

        property string title: ""
        property string detail: ""

        Text {
            width: rowText.width
            text: rowText.title
            color: Colors.base05
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeSm
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: rowText.width
            visible: text.length > 0
            text: rowText.detail
            color: Colors.base04
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeSm
            elide: Text.ElideRight
        }
    }

    // A single notification, or a collapsed stack shown by its newest one: a
    // stack's click opens it and its clear button clears all of it.
    component NotificationRow: Item {
        id: row

        required property var modelData
        property string stackKey: ""
        property var stackEntries: [modelData]

        readonly property bool stacked: stackEntries.length > 1
        readonly property bool hovered: rowHover.hovered

        x: root.fillInset
        width: parent.width - x * 2
        height: StylePopover.listRowHeight

        HoverHandler {
            id: rowHover
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (row.stacked) {
                    root.setExpanded(row.stackKey, true)
                    return
                }

                Services.NotificationCenter.activate(row.modelData)
                root.collapseRequested()
            }
        }

        NotificationIcon {
            id: rowIcon

            x: StylePopover.contentPaddingH - root.fillInset
            anchors.verticalCenter: parent.verticalCenter
            width: StylePopover.rowGlyphWellSize
            height: width
            image: row.modelData.image
            iconName: row.modelData.appIcon
            desktopEntry: row.modelData.desktopEntry
        }

        RowText {
            anchors.left: rowIcon.right
            anchors.leftMargin: StyleTokens.space10
            anchors.right: trailing.left
            anchors.rightMargin: StyleTokens.space8
            anchors.verticalCenter: parent.verticalCenter
            title: row.modelData.summary || row.modelData.appName
            detail: row.modelData.body || (row.modelData.summary ? row.modelData.appName : "")
        }

        // One width for the time and the clear button that replaces it on
        // hover, so the text beside them does not re-elide under the pointer.
        Item {
            id: trailing

            anchors.right: parent.right
            anchors.rightMargin: StylePopover.contentPaddingH - root.fillInset
            width: Math.max(timeColumn.implicitWidth, clearButton.implicitWidth)
            height: parent.height

            Column {
                id: timeColumn

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: StyleTokens.space4
                visible: !row.hovered

                Text {
                    anchors.right: parent.right
                    text: root.timeLabel(row.modelData.time)
                    color: Colors.base04
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeXs
                }

                Row {
                    anchors.right: parent.right
                    spacing: StyleTokens.space4

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.stackEntries.some((entry) => !entry.seen)
                        width: StyleNotification.unseenDotSize
                        height: width
                        radius: width / 2
                        color: Colors.base0D
                    }

                    Rectangle {
                        visible: row.stacked
                        width: stackCount.implicitWidth + StyleNotification.stackCountPaddingH * 2
                        height: stackCount.implicitHeight + StyleNotification.stackCountPaddingV * 2
                        radius: StyleTokens.radiusXs
                        color: StyleTokens.alphaLight

                        Text {
                            id: stackCount

                            anchors.centerIn: parent
                            text: row.stackEntries.length
                            color: Colors.base05
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeXs
                        }
                    }
                }
            }

            Button {
                id: clearButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: row.hovered
                iconSource: IconRegistry.themeIcon("window-close-symbolic")
                interactive: true
                Accessible.name: row.stacked ? "Clear all" : "Clear"
                onClicked: Services.NotificationCenter.remove(row.stackEntries)
            }
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Item {
        implicitWidth: StyleIsland.pageWidth
        implicitHeight: content.implicitHeight
        width: implicitWidth
        height: implicitHeight

        Column {
            id: content

            width: parent.width
            spacing: 0

            PopoverHeader {
                width: parent.width
                title: "Notifications"

                Row {
                    spacing: StyleTokens.space4

                    Button {
                        anchors.verticalCenter: parent.verticalCenter
                        iconSource: IconRegistry.themeIcon(Services.NotificationCenter.doNotDisturb ? "notifications-disabled-symbolic" : "notification-symbolic")
                        active: Services.NotificationCenter.doNotDisturb
                        interactive: true
                        Accessible.name: "Do not disturb"
                        onClicked: Services.NotificationCenter.setDoNotDisturb(!Services.NotificationCenter.doNotDisturb)
                    }

                    PillButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.empty
                        text: "Clear all"
                        onClicked: Services.NotificationCenter.clear()
                    }
                }
            }

            PopoverSeparator {
                width: parent.width
            }

            Flickable {
                id: list

                width: parent.width
                height: Math.min(rows.implicitHeight, StylePopover.listMaxHeight + root.listReach)
                contentWidth: width
                contentHeight: rows.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                SlidingHighlight {
                    run: rows
                }

                Column {
                    id: rows

                    width: list.width
                    topPadding: root.listStartPadding
                    bottomPadding: root.listEndPadding
                    spacing: StylePopover.listRowSpacing

                    Item {
                        id: updateCard

                        // Its own fill keeps it out of the rows' travelling one.
                        readonly property bool hovered: false

                        visible: root.systemUpdate !== null
                        x: root.fillInset
                        width: rows.width - x * 2
                        height: StylePopover.listRowHeight

                        Rectangle {
                            anchors.fill: parent
                            radius: StylePopover.listRowRadius
                            color: StyleTokens.alphaLight
                        }

                        NotificationIcon {
                            id: updateIcon

                            x: StylePopover.contentPaddingH - root.fillInset
                            anchors.verticalCenter: parent.verticalCenter
                            width: StylePopover.rowGlyphWellSize
                            height: width
                            iconName: root.systemUpdate?.appIcon ?? ""
                        }

                        RowText {
                            anchors.left: updateIcon.right
                            anchors.leftMargin: StyleTokens.space10
                            anchors.right: updateButton.left
                            anchors.rightMargin: StyleTokens.space8
                            anchors.verticalCenter: parent.verticalCenter
                            title: root.systemUpdate?.summary ?? ""
                            detail: root.systemUpdate?.body ?? ""
                        }

                        PillButton {
                            id: updateButton

                            anchors.right: parent.right
                            anchors.rightMargin: StylePopover.contentPaddingH - root.fillInset
                            anchors.verticalCenter: parent.verticalCenter
                            active: true
                            text: "Update"
                            onClicked: {
                                Services.NotificationCenter.runSystemUpdate(root.systemUpdate)
                                root.collapseRequested()
                            }
                        }
                    }

                    Repeater {
                        model: root.sections

                        Column {
                            id: section

                            required property var modelData
                            required property int index

                            width: rows.width
                            spacing: StylePopover.listRowSpacing

                            PopoverSection {
                                width: parent.width
                                label: section.modelData.label
                                topGap: section.index > 0 || root.systemUpdate !== null ? StylePopover.sectionTopGap : 0
                            }

                            Repeater {
                                model: section.modelData.stacks

                                Column {
                                    id: stack

                                    required property var modelData

                                    readonly property bool expanded: modelData.entries.length > 1 && root.expandedStacks.includes(modelData.key)

                                    width: rows.width
                                    spacing: StylePopover.listRowSpacing

                                    // Its buttons keep their own fills, out of
                                    // the rows' travelling one.
                                    Item {
                                        readonly property bool hovered: false

                                        visible: stack.expanded
                                        width: parent.width
                                        height: stackHeader.height

                                        PopoverSection {
                                            id: stackHeader

                                            width: parent.width
                                            label: stack.modelData.appName

                                            Row {
                                                spacing: StyleTokens.space2

                                                Button {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "Show less"
                                                    interactive: true
                                                    onClicked: root.setExpanded(stack.modelData.key, false)
                                                }

                                                Button {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    iconSource: IconRegistry.themeIcon("window-close-symbolic")
                                                    interactive: true
                                                    Accessible.name: "Clear all"
                                                    onClicked: {
                                                        root.setExpanded(stack.modelData.key, false)
                                                        Services.NotificationCenter.remove(stack.modelData.entries)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: stack.expanded ? stack.modelData.entries : stack.modelData.entries.slice(0, 1)

                                        NotificationRow {
                                            stackKey: stack.modelData.key
                                            stackEntries: stack.expanded ? [modelData] : stack.modelData.entries
                                        }
                                    }
                                }
                            }
                        }
                    }

                    PopoverMessage {
                        visible: root.empty
                        width: parent.width
                        height: StylePopover.emptyStateHeight
                        text: "All caught up"
                    }
                }
            }
        }
    }
}
