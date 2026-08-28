import QtQuick
import qs
import qs.components
import qs.config
import qs.services as Services

// Two subjects — what to shoot, what to record — so they segment rather than
// stacking into one scroll. "What I just captured" is not a third subject
// competing with them; it is a footer that stays put while you switch.
PopoverPanel {
    id: root

    readonly property int popoverWidth: StylePopover.panelWidth
    readonly property int shotTab: 0
    readonly property int recordTab: 1

    property int tab: shotTab

    readonly property var shotEntries: [
        { "label": "Region", "icon": "shot-region", "mode": "region" },
        { "label": "Window", "icon": "shot-window", "mode": "window" },
        { "label": "Screen", "icon": "shot-screen", "mode": "output" }
    ]
    readonly property var recordEntries: [
        { "label": "Region", "icon": "record-region", "mode": "region" },
        { "label": "Screen", "icon": "record-screen", "mode": "fullscreen" }
    ]

    signal dismissRequested()

    onActiveChanged: {
        if (!active)
            tab = shotTab
    }

    Item {
        implicitWidth: root.popoverWidth
        implicitHeight: content.implicitHeight
        width: implicitWidth
        height: implicitHeight

        Column {
            id: content

            width: parent.width
            spacing: 0

            PopoverHeader {
                width: parent.width
                title: "Capture"

                PillButton {
                    iconSource: IconRegistry.captureIcon("folder")
                    paddingHorizontal: StylePopover.iconButtonPadding
                    paddingVertical: StylePopover.iconButtonPadding
                    onClicked: {
                        Services.CaptureState.openFolder()
                        root.dismissRequested()
                    }
                }
            }

            Item {
                width: parent.width
                height: StylePopover.headerHeight - StyleTokens.space8

                SegmentedControl {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: StylePopover.contentPaddingH
                    anchors.rightMargin: StylePopover.contentPaddingH
                    anchors.verticalCenter: parent.verticalCenter
                    labels: ["Shot", "Record"]
                    currentIndex: root.tab
                    onSegmentSelected: (index) => root.tab = index
                }
            }

            PopoverSeparator {
                width: parent.width
            }

            // Fixed height, per the segments rule: a bar popover grows upward,
            // so a content-fit body would move the segments themselves on every
            // switch and the next click would land on a different tab.
            Item {
                width: parent.width
                height: StyleCapture.bodyHeight

                // Shot has no audio row, so its tiles centre in the taller
                // body rather than top-aligning against a hole beneath them.
                Row {
                    anchors.centerIn: parent
                    visible: root.tab === root.shotTab
                    spacing: StylePopover.tileSpacing

                    Repeater {
                        model: root.shotEntries

                        PopoverAction {
                            required property var modelData

                            stacked: true
                            label: modelData.label
                            iconSource: IconRegistry.captureIcon(modelData.icon)
                            onActivated: {
                                Services.CaptureState.shoot(modelData.mode)
                                root.dismissRequested()
                            }
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    visible: root.tab === root.recordTab
                    spacing: StyleTokens.space8

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: StylePopover.tileSpacing

                        Repeater {
                            model: root.recordEntries

                            PopoverAction {
                                required property var modelData

                                stacked: true
                                label: modelData.label
                                iconSource: IconRegistry.captureIcon(modelData.icon)
                                onActivated: {
                                    Services.CaptureState.record(modelData.mode)
                                    root.dismissRequested()
                                }
                            }
                        }
                    }

                    // Remembered state, not a per-scope entry: two scopes with
                    // one switch instead of the same two listed twice.
                    Item {
                        width: parent.width
                        height: StylePopover.listRowHeight

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: StylePopover.contentPaddingH
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Include audio"
                            color: Colors.base05
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeSm
                        }

                        Toggle {
                            anchors.right: parent.right
                            anchors.rightMargin: StylePopover.contentPaddingH
                            anchors.verticalCenter: parent.verticalCenter
                            checked: Services.CaptureState.audioEnabled
                            onToggled: Services.CaptureState.audioEnabled = !Services.CaptureState.audioEnabled
                        }
                    }
                }
            }

            PopoverSeparator {
                width: parent.width
            }

            PopoverMessage {
                width: parent.width
                visible: Services.CaptureState.latestPath.length === 0
                text: "No captures yet"
            }

            Item {
                width: parent.width
                height: visible ? StylePopover.listRowHeight : 0
                visible: Services.CaptureState.latestPath.length > 0

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: StylePopover.contentPaddingH
                    anchors.right: copyLatest.left
                    anchors.rightMargin: StyleTokens.space8
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.CaptureState.latestName
                    color: Colors.base05
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeSm
                    elide: Text.ElideMiddle
                }

                PillButton {
                    id: copyLatest

                    anchors.right: parent.right
                    anchors.rightMargin: StylePopover.contentPaddingH
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Copy"
                    onClicked: Services.CaptureState.copyLatest()
                }
            }
        }
    }
}
