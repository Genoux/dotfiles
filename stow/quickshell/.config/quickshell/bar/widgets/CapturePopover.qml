import QtQuick
import qs
import qs.components
import qs.config
import qs.services as Services

// Two subjects — what to shoot, what to record — so they segment rather than
// stacking into one scroll.
PopoverPanel {
    id: root

    readonly property int popoverWidth: StylePopover.panelWidth
    readonly property int shotTab: 0
    readonly property int recordTab: 1
    readonly property int tileRowWidth: popoverWidth - StylePopover.listRowInset * 2
    readonly property int rowWidth: popoverWidth - StylePopover.contentPaddingH * 2

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

    // PopoverAction's stacked tile is a fixed 72px built for a compact icon row
    // of four, which leaves this panel's two or three modes huddled in the
    // middle. These are the panel's primary actions, so they divide its width.
    component CaptureTile: Rectangle {
        id: tile

        required property string label
        required property string iconKey

        signal activated()

        implicitHeight: StylePopover.tileHeight
        height: implicitHeight
        radius: StyleTokens.radiusSm
        color: tileArea.containsMouse ? StyleTokens.alphaLight : StyleTokens.transparent

        Behavior on color {
            ColorAnimation {
                duration: StyleTokens.easeDurationFast
                easing.type: StyleTokens.easeSymmetric
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: StyleTokens.space4

            ThemedIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                source: IconRegistry.captureIcon(tile.iconKey)
                size: StylePopover.tileIconSize
            }

            Text {
                width: tile.width
                text: tile.label
                color: Colors.base05
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeXs
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: tileArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.activated()
        }
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
            // Every popover closes on contentPaddingV; the header band above
            // bleeds to the top edge, so only the bottom carries an inset.
            bottomPadding: StylePopover.contentPaddingV

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

            PopoverSeparator {
                width: parent.width
            }

            Item {
                width: parent.width
                implicitHeight: StylePopover.segmentBarHeight
                    + StylePopover.segmentBandPaddingTop
                    + StylePopover.segmentBandPaddingBottom
                height: implicitHeight

                SegmentedControl {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: StylePopover.contentPaddingH
                    anchors.rightMargin: StylePopover.contentPaddingH
                    anchors.top: parent.top
                    anchors.topMargin: StylePopover.segmentBandPaddingTop
                    labels: ["Shot", "Record"]
                    currentIndex: root.tab
                    onSegmentSelected: (index) => root.tab = index
                }
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
                    spacing: StyleTokens.space4

                    Repeater {
                        model: root.shotEntries

                        CaptureTile {
                            required property var modelData

                            width: (root.tileRowWidth - StyleTokens.space4 * (root.shotEntries.length - 1))
                                / root.shotEntries.length
                            label: modelData.label
                            iconKey: modelData.icon
                            onActivated: {
                                Services.CaptureState.shoot(modelData.mode)
                                root.dismissRequested()
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: root.tab === root.recordTab
                    width: root.tileRowWidth
                    spacing: StyleTokens.space8

                    Row {
                        width: parent.width
                        spacing: StyleTokens.space4

                        Repeater {
                            model: root.recordEntries

                            CaptureTile {
                                required property var modelData

                                width: (root.tileRowWidth - StyleTokens.space4 * (root.recordEntries.length - 1))
                                    / root.recordEntries.length
                                label: modelData.label
                                iconKey: modelData.icon
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
                            anchors.leftMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Include audio"
                            color: Colors.base05
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeSm
                        }

                        Toggle {
                            anchors.right: parent.right
                            anchors.rightMargin: StylePopover.contentPaddingH - StylePopover.listRowInset
                            anchors.verticalCenter: parent.verticalCenter
                            checked: Services.CaptureState.audioEnabled
                            onToggled: Services.CaptureState.audioEnabled = !Services.CaptureState.audioEnabled
                        }
                    }
                }
            }
        }
    }
}
