import QtQuick
import qs
import qs.components
import qs.config

PopoverPanel {
    id: root

    property int displayYear: 0
    property int displayMonth: 0  // 1-12

    // -1 = prev (slide right-to-left), +1 = next (slide left-to-right)
    property int slideDirection: 1

    readonly property int cellSize: StylePopover.calendarCellSize
    readonly property int cellHeight: StylePopover.calendarCellHeight
    // calendarWidth matches panelWidth so cells fill it edge-to-edge with contentPaddingH on each side.
    readonly property int calendarWidth: StylePopover.panelWidth

    // Reset display to current month and refresh today snapshot on open
    onActiveChanged: {
        if (active) {
            today = new Date()
            displayYear = today.getFullYear()
            displayMonth = today.getMonth() + 1
        }
    }

    function daysInMonth(year, month) {
        return new Date(year, month, 0).getDate()
    }

    // Returns 0=Mon … 6=Sun offset for the first day of the month
    function firstWeekdayOffset(year, month) {
        const raw = new Date(year, month - 1, 1).getDay()
        return (raw + 6) % 7
    }

    // Build a 42-entry array of {day, currentMonth} for the 6-week grid
    function buildGrid(year, month) {
        const offset = firstWeekdayOffset(year, month)
        const days = daysInMonth(year, month)
        const prevDays = daysInMonth(year, month === 1 ? 12 : month - 1)
        const cells = []
        for (let i = offset - 1; i >= 0; i--)
            cells.push({ day: prevDays - i, currentMonth: false })
        for (let d = 1; d <= days; d++)
            cells.push({ day: d, currentMonth: true })
        let next = 1
        while (cells.length < 42)
            cells.push({ day: next++, currentMonth: false })
        return cells
    }

    readonly property var gridCells: buildGrid(displayYear, displayMonth)

    property var today: new Date()
    readonly property int todayYear: today.getFullYear()
    readonly property int todayMonth: today.getMonth() + 1
    readonly property int todayDay: today.getDate()

    readonly property bool viewingCurrentMonth: displayYear === todayYear && displayMonth === todayMonth

    // Day-of-week column headers, Monday-first
    readonly property var dayNames: {
        const loc = Qt.locale()
        const names = []
        for (let i = 1; i <= 7; i++)
            names.push(loc.dayName(i, Locale.ShortFormat).slice(0, 2))
        return names
    }

    function navigatePrev() {
        root.slideDirection = -1
        if (root.displayMonth === 1) {
            root.displayMonth = 12
            root.displayYear -= 1
        } else {
            root.displayMonth -= 1
        }
        slideAnim.restart()
    }

    function navigateNext() {
        root.slideDirection = 1
        if (root.displayMonth === 12) {
            root.displayMonth = 1
            root.displayYear += 1
        } else {
            root.displayMonth += 1
        }
        slideAnim.restart()
    }

    Column {
        spacing: 0

        // Header: full human date anchor line + month/year nav row
        Item {
            width: root.calendarWidth
            height: 52

            // Full date of today — anchor / orientation line
            Text {
                id: fullDateLine

                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const loc = Qt.locale()
                    return loc.dayName(root.today.getDay(), Locale.LongFormat) + ", " + loc.monthName(root.today.getMonth(), Locale.LongFormat) + " " + root.todayDay
                }
                color: Colors.base05
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
                font.weight: Font.Medium
            }

            // Month/year nav row
            Item {
                anchors.top: fullDateLine.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                height: 20

                // Prev chevron with hover circle
                Item {
                    id: prevChevronArea

                    anchors.left: parent.left
                    anchors.leftMargin: StylePopover.contentPaddingH
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: prevHover.containsMouse ? StyleTokens.alphaLight : StyleTokens.transparent
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: Colors.base04
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeSm
                    }

                    MouseArea {
                        id: prevHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigatePrev()
                    }

                }

                // Month + year label — clicking resets to current month when viewing a different month
                Text {
                    id: monthYearLabel

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.locale().standaloneMonthName(root.displayMonth - 1) + " " + root.displayYear
                    color: root.viewingCurrentMonth ? Colors.base04 : Colors.base05
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeXs

                    MouseArea {
                        anchors.fill: parent
                        // only active when browsing away from today's month
                        enabled: !root.viewingCurrentMonth
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.slideDirection = root.displayYear < root.todayYear || (root.displayYear === root.todayYear && root.displayMonth < root.todayMonth) ? 1 : -1
                            root.displayYear = root.todayYear
                            root.displayMonth = root.todayMonth
                            slideAnim.restart()
                        }
                    }

                }

                // Next chevron with hover circle
                Item {
                    id: nextChevronArea

                    anchors.right: parent.right
                    anchors.rightMargin: StylePopover.contentPaddingH
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: nextHover.containsMouse ? StyleTokens.alphaLight : StyleTokens.transparent
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: Colors.base04
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeSm
                    }

                    MouseArea {
                        id: nextHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigateNext()
                    }

                }

            }

        }

        Rectangle {
            width: root.calendarWidth
            height: StylePopover.separatorHeight
            color: StyleOverlay.borderSubtle
        }

        // Grid container — clips the slide animation
        Item {
            id: gridContainer

            width: root.calendarWidth
            height: (root.cellHeight * 7) + 4  // 1 header row + 6 day rows + bottom gap
            clip: true

            // Grid column: day-name headers + 6 week rows
            // This entire block slides + fades on month change
            Column {
                id: gridColumn

                width: parent.width
                spacing: 0

                // Day-of-week column headers
                Row {
                    // center the 7-cell grid so floor() rounding slack splits evenly
                    leftPadding: Math.floor((root.calendarWidth - root.cellSize * 7) / 2)

                    Repeater {
                        model: root.dayNames

                        Text {
                            required property var modelData

                            width: root.cellSize
                            height: root.cellHeight
                            text: modelData
                            color: Colors.base04
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeXs
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                    }

                }

                // Day grid — 6 rows × 7 cols
                Column {
                    // center the 7-cell grid so floor() rounding slack splits evenly
                    leftPadding: Math.floor((root.calendarWidth - root.cellSize * 7) / 2)
                    spacing: 0

                    Repeater {
                        model: 6

                        Row {
                            required property int index

                            readonly property int rowStart: index * 7

                            Repeater {
                                model: 7

                                Item {
                                    id: dayCell

                                    required property int index

                                    readonly property var cell: root.gridCells[parent.rowStart + index]
                                    readonly property bool isToday: cell.currentMonth
                                        && cell.day === root.todayDay
                                        && root.displayMonth === root.todayMonth
                                        && root.displayYear === root.todayYear

                                    width: root.cellSize
                                    height: root.cellHeight

                                    // Hover highlight — subtle rounded rect, not active for today
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: root.cellHeight - 2
                                        height: root.cellHeight - 2
                                        radius: (root.cellHeight - 2) / 2
                                        visible: !dayCell.isToday && cellHover.containsMouse
                                        color: StyleTokens.alphaLight
                                    }

                                    // Today: filled accent circle
                                    Rectangle {
                                        visible: dayCell.isToday
                                        anchors.centerIn: parent
                                        width: root.cellHeight - 2
                                        height: root.cellHeight - 2
                                        radius: (root.cellHeight - 2) / 2
                                        color: Colors.base0D
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCell.cell.day
                                        // today gets contrasting dark text over the accent fill
                                        color: dayCell.isToday ? Colors.base00 : (dayCell.cell.currentMonth ? Colors.base05 : Colors.base04)
                                        opacity: dayCell.cell.currentMonth ? 1.0 : 0.35
                                        font.family: StyleTokens.fontSans
                                        font.pixelSize: StyleTokens.fontSizeXs
                                        font.weight: dayCell.isToday ? Font.Medium : Font.Normal
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    MouseArea {
                                        id: cellHover

                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }

                                }

                            }

                        }

                    }

                }

            }

        }

        Item { width: 1; height: 6 }

    }

    // Month slide animation — restarted explicitly by the navigation handlers
    // so the programmatic month reset on popover open never triggers a slide.
    SequentialAnimation {
        id: slideAnim

        PropertyAction {
            target: gridColumn
            property: "x"
            value: root.slideDirection * 16
        }

        PropertyAction {
            target: gridColumn
            property: "opacity"
            value: 0
        }

        ParallelAnimation {
            NumberAnimation {
                target: gridColumn
                property: "x"
                to: 0
                duration: 180
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: gridColumn
                property: "opacity"
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }

        }

    }

}
