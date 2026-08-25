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

    // Debounces scroll-to-navigate so one trackpad swipe (many wheel deltas)
    // moves a single month instead of flying through several.
    property bool wheelLocked: false

    readonly property int cellSize: StylePopover.calendarCellSize
    readonly property int calendarWidth: StylePopover.calendarWidth
    readonly property int padH: StylePopover.calendarPaddingH

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

    function jumpToToday() {
        if (root.viewingCurrentMonth)
            return
        root.slideDirection = root.displayYear < root.todayYear || (root.displayYear === root.todayYear && root.displayMonth < root.todayMonth) ? 1 : -1
        root.displayYear = root.todayYear
        root.displayMonth = root.todayMonth
        slideAnim.restart()
    }

    Column {
        // Explicit width so PopoverPanel's implicitWidth is stable at build
        // time rather than waiting on childrenRect of unloaded positioners.
        width: root.calendarWidth
        bottomPadding: StylePopover.contentPaddingV
        spacing: 0

        // Hero row: today's full date is the glanceable anchor, so it gets the
        // largest type here. The Today pill sits opposite it, out of the way of
        // the centered month title below.
        PopoverHeader {
            width: root.calendarWidth
            implicitWidth: root.calendarWidth
            title: {
                const loc = Qt.locale()
                return loc.dayName(root.today.getDay(), Locale.LongFormat) + ", " + loc.monthName(root.today.getMonth(), Locale.LongFormat) + " " + root.todayDay
            }

            // Explicit jump-back control — only meaningful while browsing away
            PillButton {
                visible: !root.viewingCurrentMonth
                text: "Today"
                onClicked: root.jumpToToday()
            }

        }

        PopoverSeparator {
            width: root.calendarWidth
            implicitWidth: root.calendarWidth
        }

        // Month nav: prev far left, title centered, next far right — the layout
        // every desktop calendar converges on.
        Item {
            width: root.calendarWidth
            height: StylePopover.calendarNavHeight

            // Centers the nav button on the outermost grid column below it
            readonly property int navMargin: root.padH + (root.cellSize - StylePopover.calendarNavSize) / 2

            Button {
                anchors.left: parent.left
                anchors.leftMargin: parent.navMargin
                anchors.verticalCenter: parent.verticalCenter
                width: StylePopover.calendarNavSize
                height: StylePopover.calendarNavSize
                radius: width / 2
                iconGlyph: "‹"
                iconFont: StyleTokens.fontSans
                iconSize: StyleControl.iconSizeMd
                foreground: Colors.base05
                interactive: true
                onClicked: root.navigatePrev()
            }

            Text {
                anchors.centerIn: parent
                text: Qt.locale().standaloneMonthName(root.displayMonth - 1) + " " + root.displayYear
                color: Colors.base05
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeMd
                font.weight: Font.DemiBold
            }

            Button {
                anchors.right: parent.right
                anchors.rightMargin: parent.navMargin
                anchors.verticalCenter: parent.verticalCenter
                width: StylePopover.calendarNavSize
                height: StylePopover.calendarNavSize
                radius: width / 2
                iconGlyph: "›"
                iconFont: StyleTokens.fontSans
                iconSize: StyleControl.iconSizeMd
                foreground: Colors.base05
                interactive: true
                onClicked: root.navigateNext()
            }

        }

        // Grid container — clips the slide animation
        Item {
            id: gridContainer

            width: root.calendarWidth
            height: StylePopover.calendarWeekdayRowHeight + root.cellSize * 6
            clip: true

            // Grid column: weekday headers + 6 week rows.
            // This entire block slides + fades on month change.
            Column {
                id: gridColumn

                width: parent.width
                spacing: 0

                Row {
                    x: root.padH

                    Repeater {
                        model: root.dayNames

                        EyebrowLabel {
                            required property var modelData

                            width: root.cellSize
                            height: StylePopover.calendarWeekdayRowHeight
                            text: modelData
                            font.pixelSize: StyleTokens.fontSizeSm
                            horizontalAlignment: Text.AlignHCenter
                        }

                    }

                }

                // Day grid — 6 rows × 7 cols
                Column {
                    x: root.padH
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
                                    height: root.cellSize

                                    // Hover highlight — suppressed on today, which already has a fill
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: StylePopover.calendarDayCircle
                                        height: StylePopover.calendarDayCircle
                                        radius: width / 2
                                        visible: !dayCell.isToday && cellHover.containsMouse
                                        color: StyleTokens.alphaLight
                                    }

                                    // Today: filled accent circle
                                    Rectangle {
                                        anchors.centerIn: parent
                                        visible: dayCell.isToday
                                        width: StylePopover.calendarDayCircle
                                        height: StylePopover.calendarDayCircle
                                        radius: width / 2
                                        color: Colors.base0D
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCell.cell.day
                                        // today gets contrasting dark text over the accent fill
                                        color: dayCell.isToday ? Colors.base00 : Colors.base05
                                        opacity: dayCell.cell.currentMonth ? 1 : StylePopover.calendarOtherMonthOpacity
                                        font.family: StyleTokens.fontSans
                                        font.pixelSize: StyleTokens.fontSizeMd
                                        font.weight: dayCell.isToday ? Font.DemiBold : Font.Normal
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

            // Wheel-only overlay: NoButton + hover disabled lets day-cell hover
            // pass through underneath while still catching scroll.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (root.wheelLocked)
                        return
                    if (wheel.angleDelta.y < 0)
                        root.navigateNext()
                    else if (wheel.angleDelta.y > 0)
                        root.navigatePrev()
                    root.wheelLocked = true
                    wheelUnlockTimer.restart()
                }
            }

        }

    }

    Timer {
        id: wheelUnlockTimer

        interval: StylePopover.calendarWheelDebounce
        onTriggered: root.wheelLocked = false
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
