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
    readonly property int tileRowWidth: popoverWidth - fillInset * 2

    // A live session opens on its controls; otherwise the panel opens on Shot.
    readonly property int restingTab: Services.CaptureState.recording ? recordTab : shotTab
    property int tab: restingTab

    readonly property var shotEntries: [
        { "label": "Region", "icon": "shot-region", "mode": "region" },
        { "label": "Window", "icon": "shot-window", "mode": "window" },
        { "label": "Screen", "icon": "shot-screen", "mode": "output" }
    ]
    // Audio rides in the tile row rather than a row of its own beneath it, so
    // both tabs are exactly one row tall and neither pads out to match the
    // other. It states its value with the glyph, like the mute button does.
    readonly property var recordEntries: [
        { "label": "Region", "icon": "record-region", "mode": "region" },
        { "label": "Screen", "icon": "record-screen", "mode": "fullscreen" },
        { "label": "Audio", "icon": "", "mode": "" }
    ]

    signal dismissRequested()

    onDismissFinished: {
        if (!active)
            tab = restingTab
    }
    onRestingTabChanged: {
        if (!active)
            tab = restingTab
    }

    // A session that ends while the panel is open would swap the record tiles
    // in under the pointer, and a click aimed at Pause would land on Screen
    // and start a new recording. Closing is the only safe answer.
    Connections {
        target: Services.CaptureState

        function onRecordingChanged() {
            if (!Services.CaptureState.recording && root.active)
                root.dismissRequested()
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

            PopoverHeader {
                width: parent.width
                title: "Capture"

                Row {
                    spacing: StyleTokens.space4

                    // States its value with the label, like the audio tile
                    // states its own with the glyph. Grows leftward, so the
                    // folder button never moves under the pointer.
                    PillButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconSource: IconRegistry.captureIcon("delay")
                        text: Services.CaptureState.delaySeconds > 0
                            ? Services.CaptureState.delaySeconds + "s"
                            : ""
                        active: Services.CaptureState.delaySeconds > 0
                        paddingHorizontal: hasText
                            ? StylePopover.pillPaddingH
                            : StylePopover.iconButtonPadding
                        paddingVertical: StylePopover.iconButtonPadding
                        onClicked: Services.CaptureState.cycleDelay()
                    }

                    PillButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconSource: IconRegistry.captureIcon("folder")
                        paddingHorizontal: StylePopover.iconButtonPadding
                        paddingVertical: StylePopover.iconButtonPadding
                        onClicked: {
                            Services.CaptureState.openFolder()
                            root.dismissRequested()
                        }
                    }
                }
            }

            PopoverSeparator {
                width: parent.width
            }

            Item {
                width: parent.width
                implicitHeight: StyleControl.segmentHeight
                    + root.bandPaddingTop
                    + root.bandPaddingBottom
                height: implicitHeight

                SegmentedControl {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: root.fillInset
                    anchors.rightMargin: root.fillInset
                    anchors.top: parent.top
                    anchors.topMargin: root.bandPaddingTop
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
                height: root.embedded ? StylePopover.tileHeight : StyleCapture.bodyHeight

                // Shot has no audio row, so its tiles centre in the taller
                // body rather than top-aligning against a hole beneath them.
                SlidingHighlight {
                    run: shotTileRow
                }

                Row {
                    id: shotTileRow

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    visible: root.tab === root.shotTab
                    spacing: root.bandGap

                    Repeater {
                        model: root.shotEntries

                        PopoverTile {
                            required property var modelData

                            width: (root.tileRowWidth - root.bandGap * (root.shotEntries.length - 1))
                                / root.shotEntries.length
                            label: modelData.label
                            iconSource: IconRegistry.captureIcon(modelData.icon)
                            onActivated: {
                                Services.CaptureState.shoot(modelData.mode)
                                root.dismissRequested()
                            }
                        }
                    }
                }

                SlidingHighlight {
                    run: recordTileRow
                }

                Row {
                    id: recordTileRow

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    visible: root.tab === root.recordTab && !Services.CaptureState.recording
                    spacing: root.bandGap

                    Repeater {
                        model: root.recordEntries

                        PopoverTile {
                            required property var modelData

                            readonly property bool isAudio: modelData.mode.length === 0

                            width: (root.tileRowWidth - root.bandGap * (root.recordEntries.length - 1))
                                / root.recordEntries.length
                            label: modelData.label
                            iconSource: IconRegistry.captureIcon(isAudio
                                ? (Services.CaptureState.audioEnabled ? "audio-on" : "audio-off")
                                : modelData.icon)
                            active: isAudio && Services.CaptureState.audioEnabled
                            onActivated: {
                                if (isAudio) {
                                    Services.CaptureState.audioEnabled = !Services.CaptureState.audioEnabled
                                    return
                                }
                                Services.CaptureState.record(modelData.mode)
                                root.dismissRequested()
                            }
                        }
                    }
                }

                // The Record tab becomes the session while one runs: the same
                // three columns as the tiles it replaces, so the panel keeps
                // its shape and only the contents change. The first column is
                // read-out, not an action, so it carries no hover and the
                // travelling fill skips it.
                SlidingHighlight {
                    run: sessionRow
                }

                Row {
                    id: sessionRow

                    readonly property int columnWidth: (root.tileRowWidth - root.bandGap * 2) / 3
                    readonly property bool paused: Services.CaptureState.recordingPaused

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    visible: root.tab === root.recordTab && Services.CaptureState.recording
                    spacing: root.bandGap

                    Item {
                        width: sessionRow.columnWidth
                        height: StylePopover.tileHeight

                        // Mirrors a tile: a 20px line where the glyph sits,
                        // then the label on the tiles' own baseline.
                        Column {
                            anchors.centerIn: parent
                            spacing: StyleTokens.space4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: StylePopover.tileIconSize
                                text: Services.CaptureState.formatDuration(Services.CaptureState.recordingSeconds)
                                color: sessionRow.paused ? Colors.base04 : Colors.base06
                                font.family: StyleTokens.fontMono
                                font.pixelSize: StyleTokens.fontSizeLg
                                verticalAlignment: Text.AlignVCenter
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: StyleTokens.space4

                                RecordingDot {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: StyleTokens.space6
                                    implicitHeight: StyleTokens.space6
                                    paused: sessionRow.paused
                                }

                                Text {
                                    text: sessionRow.paused ? "Paused" : "Recording"
                                    color: Colors.base04
                                    font.family: StyleTokens.fontSans
                                    font.pixelSize: StyleTokens.fontSizeXs
                                }
                            }
                        }
                    }

                    PopoverTile {
                        width: sessionRow.columnWidth
                        label: sessionRow.paused ? "Resume" : "Pause"
                        iconSource: IconRegistry.captureIcon(sessionRow.paused ? "resume" : "pause")
                        onActivated: Services.CaptureState.togglePause()
                    }

                    // Dismisses: stopping hands the file to the preview card,
                    // which is where attention goes next.
                    PopoverTile {
                        width: sessionRow.columnWidth
                        label: "Stop"
                        iconSource: IconRegistry.captureIcon("stop")
                        onActivated: {
                            Services.CaptureState.stopRecording()
                            root.dismissRequested()
                        }
                    }
                }
            }
        }
    }
}
