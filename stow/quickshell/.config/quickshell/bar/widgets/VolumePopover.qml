import QtQuick
import qs
import qs.components
import qs.config
import qs.services

PopoverPanel {
    id: root

    flushBottom: true
    underFooter: true

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

    onTabChanged: {
        Qt.callLater(root.revealSelected)
        listFade.restart()
    }

    onDismissFinished: {
        if (!active)
            root.tab = root.outputTab
    }

    Component.onCompleted: Qt.callLater(root.revealSelected)

    Connections {
        target: AudioState

        function onNodeRevisionChanged() {
            if (!root.active)
                Qt.callLater(root.revealSelected)
        }

        function onSinkChanged() {
            if (!root.active)
                Qt.callLater(root.revealSelected)
        }

        function onSourceChanged() {
            if (!root.active)
                Qt.callLater(root.revealSelected)
        }
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
                implicitHeight: StyleControl.segmentHeight
                    + root.bandPaddingTop
                    + root.bandPaddingBottom
                height: implicitHeight

                SegmentedControl {
                    id: segments

                    anchors.left: parent.left
                    anchors.leftMargin: root.fillInset
                    anchors.right: parent.right
                    anchors.rightMargin: root.fillInset
                    anchors.top: parent.top
                    anchors.topMargin: root.bandPaddingTop
                    labels: ["Output", "Input", "Apps"]
                    currentIndex: root.tab
                    onSegmentSelected: (index) => root.tab = index
                }
            }

            // Level band -- one pill carrying the level; its glyph is the mute
            // toggle, so the control that shows the level is also the one that
            // silences it.
            Item {
                width: parent.width
                // In the island the gap below the bar is the list's own top
                // padding, the same as the gap the segment band leaves above it.
                implicitHeight: StyleControl.levelBarHeight + (root.embedded ? 0 : StylePopover.contentPaddingV * 2)
                height: implicitHeight

                LevelBar {
                    id: levelBar

                    anchors.left: parent.left
                    anchors.leftMargin: root.fillInset
                    anchors.right: parent.right
                    anchors.rightMargin: root.fillInset
                    anchors.top: parent.top
                    anchors.topMargin: root.embedded ? 0 : StylePopover.contentPaddingV
                    enabled: !!root.bandNode
                    value: root.bandVolume
                    muted: root.bandMuted
                    iconSource: root.onInput
                        ? IconRegistry.barControlIcon("microphone")
                        : IconRegistry.volumeIcon(root.bandVolume, root.bandMuted, AudioState.hasSink)
                    onMoved: (level) => AudioState.setVolume(root.bandNode, level)
                    onIconClicked: AudioState.toggleMute(root.bandNode)
                }
            }

            // The slider and the list already read as two bands from their
            // spacing; in the island a second rule is only noise.
            PopoverSeparator {
                width: parent.width
                visible: !root.embedded
            }

            Item {
                width: parent.width
                readonly property bool empty: root.tab === root.appsTab ? AudioState.streamCount === 0
                    : (root.onInput ? AudioState.inputCount === 0 : AudioState.outputCount === 0)
                implicitHeight: empty ? StylePopover.emptyStateHeight
                    : Math.min(listColumn.implicitHeight, StylePopover.soundBodyMaxHeight + root.listReach)
                height: implicitHeight

                PopoverMessage {
                    anchors.fill: parent
                    visible: parent.empty
                    text: root.tab === root.appsTab ? "Nothing playing"
                        : (root.onInput ? "No input devices" : "No output devices")
                }

                Flickable {
                    id: list

                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: listColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    // The rows change in place when a tab is picked, so the new
                    // list fades in over them instead of snapping.
                    NumberAnimation on opacity {
                        id: listFade

                        from: 0
                        to: 1
                        duration: StyleIsland.resizeDuration
                        easing.type: StyleTokens.easeFade
                    }

                    SlidingHighlight {
                        run: listColumn
                    }

                    Column {
                        id: listColumn

                        width: list.width
                        topPadding: root.listStartPadding
                        bottomPadding: root.listEndPadding
                        spacing: StylePopover.listRowSpacing

                        Repeater {
                            id: deviceRepeater

                            model: AudioState.nodes

                            AudioDeviceRow {
                                required property var modelData

                                x: root.fillInset
                                width: listColumn.width - root.fillInset * 2
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

                                x: root.fillInset
                                width: listColumn.width - root.fillInset * 2
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
