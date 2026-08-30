import QtQuick
import qs
import qs.components
import qs.config
import qs.services

PopoverPanel {
    id: root

    readonly property int outputTab: 0
    readonly property int inputTab: 1
    readonly property int appsTab: 2

    property int tab: outputTab

    readonly property bool onInput: root.tab === root.inputTab

    // The band always drives something: the mic on the Input tab, and otherwise
    // the default output — which on the Apps tab reads as the master above the
    // per-application levels, the way a mixer is laid out.
    readonly property var bandNode: root.onInput ? AudioState.source : AudioState.sink
    readonly property real bandVolume: AudioState.volumeOf(root.bandNode)
    readonly property bool bandMuted: AudioState.mutedOf(root.bandNode)

    // Opening a device tab has to answer "which one am I on" before anything
    // else. With eight outputs the current one can sit below the fold, so scroll
    // it into the middle rather than making the reader hunt for the filled dot.
    // Scanned on demand rather than reported by the rows: a delegate's y is not
    // settled at the moment its visibility flips, and chasing that ordering is
    // how a scroll position ends up one tab behind.
    function revealSelected() {
        if (root.tab === root.appsTab)
            return

        for (let index = 0; index < deviceRepeater.count; index++) {
            const item = deviceRepeater.itemAt(index)
            if (!item || !item.visible || !item.selected)
                continue

            const limit = Math.max(0, list.contentHeight - list.height)
            const centred = item.y - (list.height - item.height) / 2
            list.contentY = Math.max(0, Math.min(limit, centred))
            return
        }
    }

    onTabChanged: Qt.callLater(root.revealSelected)

    onActiveChanged: {
        if (active)
            Qt.callLater(root.revealSelected)
        else
            root.tab = root.outputTab
    }

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
                title: "Sound"
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
                    id: segments

                    anchors.left: parent.left
                    anchors.leftMargin: StylePopover.listRowInset
                    anchors.right: parent.right
                    anchors.rightMargin: StylePopover.listRowInset
                    anchors.top: parent.top
                    anchors.topMargin: StylePopover.segmentBandPaddingTop
                    labels: ["Output", "Input", "Apps"]
                    currentIndex: root.tab
                    onSegmentSelected: (index) => root.tab = index
                }
            }

            // Level band — the glyph is the mute toggle, so the control that
            // shows the level is also the one that silences it.
            Item {
                width: parent.width
                implicitHeight: StylePopover.levelBandHeight
                height: implicitHeight

                Button {
                    id: muteButton

                    anchors.left: parent.left
                    anchors.leftMargin: StylePopover.contentPaddingH - StylePopover.ghostPaddingH
                    anchors.verticalCenter: parent.verticalCenter
                    iconSource: root.onInput
                        ? IconRegistry.barControlIcon("microphone")
                        : IconRegistry.volumeIcon(root.bandVolume, root.bandMuted, AudioState.hasSink)
                    iconSize: StyleControl.iconSize
                    paddingHorizontal: StylePopover.ghostPaddingH
                    paddingVertical: StylePopover.ghostPaddingV
                    foreground: root.bandMuted ? Colors.base04 : Colors.base05
                    interactive: !!root.bandNode
                    onClicked: AudioState.toggleMute(root.bandNode)
                }

                // Fixed width so the band does not re-flow between "5%" and
                // "100%" while the slider is being dragged through them.
                Text {
                    id: readout

                    anchors.right: parent.right
                    anchors.rightMargin: StylePopover.contentPaddingH
                    anchors.verticalCenter: parent.verticalCenter
                    width: StyleTokens.space20 + StyleTokens.space12
                    text: root.bandNode ? Math.round(levelSlider.shownValue * 100) + "%" : "—"
                    color: Colors.base04
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeXs
                    horizontalAlignment: Text.AlignRight
                }

                Slider {
                    id: levelSlider

                    anchors.left: muteButton.right
                    anchors.leftMargin: StyleTokens.space6
                    anchors.right: readout.left
                    anchors.rightMargin: StyleTokens.space10
                    anchors.verticalCenter: parent.verticalCenter
                    value: root.bandVolume
                    opacity: root.bandMuted ? StyleTokens.opacityDisabled : 1
                    onMoved: (level) => AudioState.setVolume(root.bandNode, level)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: StyleTokens.easeDurationFast
                            easing.type: StyleTokens.easeStandard
                        }
                    }
                }
            }

            PopoverSeparator {
                width: parent.width
            }

            // Fixed-height body: see StylePopover.soundBodyHeight for why this
            // does not hug its content.
            Item {
                width: parent.width
                implicitHeight: StylePopover.soundBodyHeight
                height: implicitHeight

                PopoverMessage {
                    anchors.fill: parent
                    visible: root.tab === root.appsTab && AudioState.streamCount === 0
                    text: "Nothing playing"
                }

                Flickable {
                    id: list

                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: listColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    Column {
                        id: listColumn

                        width: list.width
                        topPadding: StylePopover.contentPaddingV
                        bottomPadding: StylePopover.contentPaddingV
                        spacing: StylePopover.listRowSpacing

                        Repeater {
                            id: deviceRepeater

                            model: AudioState.nodes

                            AudioDeviceRow {
                                required property var modelData

                                x: StylePopover.listRowInset
                                width: listColumn.width - StylePopover.listRowInset * 2
                                node: modelData
                                visible: root.onInput
                                    ? AudioState.isInput(modelData)
                                    : (root.tab === root.outputTab && AudioState.isOutput(modelData))
                                selected: root.onInput
                                    ? AudioState.isDefaultInput(modelData)
                                    : AudioState.isDefaultOutput(modelData)
                                onActivated: {
                                    if (root.onInput)
                                        AudioState.selectInput(modelData)
                                    else
                                        AudioState.selectOutput(modelData)
                                }
                            }
                        }

                        Repeater {
                            model: AudioState.nodes

                            AudioStreamRow {
                                required property var modelData

                                x: StylePopover.listRowInset
                                width: listColumn.width - StylePopover.listRowInset * 2
                                node: modelData
                                visible: root.tab === root.appsTab && AudioState.isPlaybackStream(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
