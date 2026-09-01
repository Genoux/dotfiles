import QtQuick
import qs
import qs.components
import qs.config
import qs.services

PopoverPanel {
    id: root

    readonly property int popoverWidth: StylePopover.systemMonitorWidth
    property string sortKey: "cpu"
    property bool sortAscending: false
    readonly property var visibleProcesses: {
        const sorted = SystemMonitor.processes.slice()
        const direction = sortAscending ? 1 : -1
        sorted.sort((left, right) => {
            const difference = Number(left[sortKey]) - Number(right[sortKey])
            if (difference !== 0)
                return difference * direction
            return String(left.name).localeCompare(String(right.name))
        })
        return sorted.slice(0, StylePopover.systemProcessRowCount)
    }

    onActiveChanged: SystemMonitor.active = active

    signal btopRequested()

    function toggleSort(key) {
        if (sortKey === key)
            sortAscending = !sortAscending
        else {
            sortKey = key
            sortAscending = false
        }
    }

    function sortLabel(key, label) {
        if (sortKey !== key)
            return label
        return label + (sortAscending ? " ↑" : " ↓")
    }

    component Metric: Item {
        required property string label
        required property real value
        required property string detail
        required property color accent

        height: StylePopover.systemMetricHeight

        Column {
            anchors.fill: parent
            spacing: StyleTokens.space6

            EyebrowLabel {
                width: parent.width
                text: label
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: Math.round(value) + "%"
                color: Colors.base05
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeLg
                font.weight: Font.DemiBold
            }

            Rectangle {
                width: parent.width
                height: StylePopover.systemMeterHeight
                radius: height / 2
                color: StyleTokens.alphaHairline

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, value / 100))
                    height: parent.height
                    radius: parent.radius
                    color: accent
                }
            }

            Text {
                width: parent.width
                text: detail
                color: Colors.base04
                font.family: StyleTokens.fontMono
                font.pixelSize: StyleTokens.fontSizeXs
                elide: Text.ElideRight
            }
        }
    }

    Item {
        width: root.popoverWidth
        implicitWidth: width
        implicitHeight: content.implicitHeight
        height: implicitHeight

        Column {
            id: content

            width: parent.width
            spacing: 0

            PopoverHeader {
                width: parent.width
                title: "System"
                horizontalPadding: StylePopover.systemHeaderPaddingH

                Row {
                    spacing: StyleTokens.space8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: SystemMonitor.loaded ? "up " + SystemMonitor.uptime : "Sampling…"
                        color: Colors.base04
                        font.family: StyleTokens.fontMono
                        font.pixelSize: StyleTokens.fontSizeXs
                    }

                    Button {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "utilities-terminal-symbolic"
                        interactive: true
                        onClicked: root.btopRequested()
                    }
                }
            }

            PopoverSeparator {
                width: parent.width
            }

            Item {
                width: parent.width
                height: StylePopover.systemSummaryHeight

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: StylePopover.contentPaddingH
                    anchors.right: parent.right
                    anchors.rightMargin: StylePopover.contentPaddingH
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: StyleTokens.space12

                    Metric {
                        width: (parent.width - parent.spacing * 2) / 3
                        label: "CPU"
                        value: SystemMonitor.cpuUsage
                        detail: Temperature.value
                        accent: Colors.base0D
                    }

                    Metric {
                        width: (parent.width - parent.spacing * 2) / 3
                        label: "Memory"
                        value: SystemMonitor.memoryUsage
                        detail: SystemMonitor.memoryDetail
                        accent: Colors.base0E
                    }

                    Metric {
                        width: (parent.width - parent.spacing * 2) / 3
                        label: "Disk /"
                        value: SystemMonitor.diskUsage
                        detail: SystemMonitor.diskDetail
                        accent: Colors.base0B
                    }
                }
            }

            PopoverSeparator {
                width: parent.width
            }

            PopoverSection {
                width: parent.width
                topGap: StylePopover.sectionTopGap
                label: "Top processes"

                Row {
                    spacing: StyleTokens.space12

                    Button {
                        width: StylePopover.systemProcessValueWidth
                        minimumWidth: 0
                        text: root.sortLabel("cpu", "CPU")
                        fontSize: StyleTokens.fontSizeXs
                        paddingHorizontal: 0
                        paddingVertical: StylePopover.iconButtonPadding
                        interactive: true
                        active: root.sortKey === "cpu"
                        activeBackground: StyleTokens.alphaLight
                        foreground: active ? Colors.base05 : Colors.base04
                        onClicked: root.toggleSort("cpu")
                    }

                    Button {
                        width: StylePopover.systemProcessValueWidth
                        minimumWidth: 0
                        text: root.sortLabel("memory", "RAM")
                        fontSize: StyleTokens.fontSizeXs
                        paddingHorizontal: 0
                        paddingVertical: StylePopover.iconButtonPadding
                        interactive: true
                        active: root.sortKey === "memory"
                        activeBackground: StyleTokens.alphaLight
                        foreground: active ? Colors.base05 : Colors.base04
                        onClicked: root.toggleSort("memory")
                    }
                }
            }

            Item {
                width: parent.width
                height: StylePopover.systemProcessListHeight

                PopoverMessage {
                    anchors.fill: parent
                    visible: !SystemMonitor.loaded
                    text: "Sampling processes…"
                }

                Column {
                    anchors.fill: parent
                    visible: SystemMonitor.loaded
                    topPadding: StyleTokens.space4
                    bottomPadding: StyleTokens.space4
                    spacing: 0

                    Repeater {
                        model: root.visibleProcesses

                        Rectangle {
                            id: processRow

                            required property var modelData

                            x: StylePopover.listRowInset
                            width: root.popoverWidth - StylePopover.listRowInset * 2
                            height: StylePopover.systemProcessRowHeight
                            radius: StyleTokens.radiusSm
                            color: processHover.hovered ? StyleTokens.alphaLight : StyleTokens.transparent

                            Behavior on color {
                                ColorAnimation {
                                    duration: StyleTokens.easeDurationFast
                                    easing.type: StyleTokens.easeSymmetric
                                }
                            }

                            HoverHandler {
                                id: processHover
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
                                anchors.right: values.left
                                anchors.rightMargin: StyleTokens.space6
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: Colors.base05
                                font.family: StyleTokens.fontSans
                                font.pixelSize: StyleTokens.fontSizeSm
                                elide: Text.ElideRight
                            }

                            Row {
                                id: values

                                anchors.right: parent.right
                                anchors.rightMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: StyleTokens.space12

                                Text {
                                    width: StylePopover.systemProcessValueWidth
                                    text: modelData.cpu.toFixed(1) + "%"
                                    color: Colors.base05
                                    font.family: StyleTokens.fontMono
                                    font.pixelSize: StyleTokens.fontSizeXs
                                    horizontalAlignment: Text.AlignRight
                                }

                                Text {
                                    width: StylePopover.systemProcessValueWidth
                                    text: modelData.memory.toFixed(1) + "%"
                                    color: Colors.base04
                                    font.family: StyleTokens.fontMono
                                    font.pixelSize: StyleTokens.fontSizeXs
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
