import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.bar.widgets as Widgets
import qs.components
import qs.config
import qs.services as Services

PanelWindow {
    id: root

    required property var screen

    readonly property bool active: Services.ComponentGallery.visible
        && Services.ComponentGallery.screen === root.screen
    readonly property int galleryMargin: StyleTokens.space20 * 2
    readonly property int surfaceWidth: Math.min(1080, Math.max(640, root.screen.width - galleryMargin * 2))
    readonly property int availableHeight: Math.max(480, root.screen.height - galleryMargin * 2)
    readonly property int surfaceHeight: Math.min(820, availableHeight)

    property bool displayed: false
    property bool toggleValue: true
    property real sliderValue: 0.62
    property int segmentIndex: 1
    property int signalStrength: 3
    property int galleryPage: 0
    property string lastAction: "Nothing selected yet"

    onGalleryPageChanged: {
        galleryFlick.contentY = 0
        galleryMasonry.scheduleLayout()
    }

    screen: root.screen
    visible: displayed
    color: StyleTokens.transparent
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onActiveChanged: {
        if (active) {
            surface.stopHide()
            displayed = true
            surface.show()
            Qt.callLater(() => keyboardScope.forceActiveFocus())
        } else {
            surface.hide()
        }
    }

    component GalleryCard: Rectangle {
        id: card

        required property string title
        property int page: 0
        default property alias content: cardContent.data

        visible: root.galleryPage === page
        implicitHeight: cardColumn.implicitHeight + StyleTokens.space16 * 2
        radius: StyleTokens.radiusMd
        color: StyleTokens.alphaHairline
        border.width: StyleTokens.borderWidth
        border.color: StyleOverlay.borderSubtle

        onImplicitHeightChanged: {
            if (parent && parent.scheduleLayout)
                parent.scheduleLayout()
        }
        onVisibleChanged: {
            if (parent && parent.scheduleLayout)
                parent.scheduleLayout()
        }

        Column {
            id: cardColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: StyleTokens.space16
            spacing: StyleTokens.space12

            Column {
                width: parent.width

                Text {
                    width: parent.width
                    text: card.title
                    color: Colors.base05
                    font.family: StyleTokens.fontSans
                    font.pixelSize: StyleTokens.fontSizeMd
                    font.weight: Font.DemiBold
                }
            }

            Column {
                id: cardContent

                width: parent.width
                spacing: StyleTokens.space12
            }
        }
    }

    // GridLayout makes every card in a row as tall as its tallest neighbour,
    // leaving large blank bands under short previews. Place each card in the
    // currently shortest column instead so the gallery stays dense while card
    // heights remain fully content-driven.
    component GalleryMasonry: Item {
        id: masonry

        property int spacing: StyleTokens.space12
        readonly property int columnCount: width >= 840 ? 2 : 1
        property real laidOutHeight: 0

        implicitHeight: laidOutHeight

        function scheduleLayout() {
            layoutTimer.restart()
        }

        function relayout() {
            const heights = []
            for (let column = 0; column < columnCount; column++)
                heights.push(0)

            const columnWidth = (width - spacing * (columnCount - 1)) / columnCount
            for (let index = 0; index < children.length; index++) {
                const child = children[index]
                if (!child.visible)
                    continue

                let targetColumn = 0
                for (let column = 1; column < columnCount; column++) {
                    if (heights[column] < heights[targetColumn])
                        targetColumn = column
                }

                child.width = columnWidth
                child.x = targetColumn * (columnWidth + spacing)
                child.y = heights[targetColumn]
                heights[targetColumn] += child.implicitHeight + spacing
            }

            laidOutHeight = Math.max(...heights) - spacing
        }

        onWidthChanged: scheduleLayout()
        onColumnCountChanged: scheduleLayout()
        Component.onCompleted: scheduleLayout()

        Timer {
            id: layoutTimer

            interval: 0
            onTriggered: masonry.relayout()
        }
    }

    OverlayPanel {
        id: surface

        width: root.surfaceWidth
        height: root.surfaceHeight
        anchors.centerIn: parent
        active: root.active
        onHideFinished: root.displayed = false

        FocusScope {
            id: keyboardScope

            anchors.fill: parent

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    Services.ComponentGallery.close()
                    event.accepted = true
                }
            }

            Column {
                anchors.fill: parent

                Item {
                    width: parent.width
                    height: 68

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: StyleTokens.space20
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Component gallery"
                        color: Colors.base05
                        font.family: StyleTokens.fontSans
                        font.pixelSize: StyleTokens.fontSizeLg
                        font.weight: Font.DemiBold
                    }

                    PillButton {
                        anchors.right: parent.right
                        anchors.rightMargin: StyleTokens.space16
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "window-close-symbolic"
                        paddingHorizontal: StylePopover.iconButtonPadding
                        paddingVertical: StylePopover.iconButtonPadding
                        onClicked: Services.ComponentGallery.close()
                    }

                    SegmentedControl {
                        width: 220
                        anchors.right: parent.right
                        anchors.rightMargin: StyleTokens.space16 + StyleControl.buttonWidth + StyleTokens.space8
                        anchors.verticalCenter: parent.verticalCenter
                        labels: ["Components", "Widgets"]
                        currentIndex: root.galleryPage
                        onSegmentSelected: (index) => root.galleryPage = index
                    }
                }

                PopoverSeparator {
                    width: parent.width
                }

                Flickable {
                    id: galleryFlick

                    width: parent.width
                    height: parent.height - 69
                    contentWidth: width
                    contentHeight: galleryMasonry.implicitHeight + StyleTokens.space16 * 2
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    GalleryMasonry {
                        id: galleryMasonry

                        x: StyleTokens.space16
                        y: StyleTokens.space16
                        width: parent.width - StyleTokens.space16 * 2

                        GalleryCard {
                            title: "Button"

                            Row {
                                spacing: StyleTokens.space8

                                Button {
                                    anchors.verticalCenter: parent.verticalCenter
                                    iconName: "system-search-symbolic"
                                    interactive: true
                                    onClicked: root.lastAction = "Icon button clicked"
                                }

                                Button {
                                    anchors.verticalCenter: parent.verticalCenter
                                    iconName: "utilities-terminal-symbolic"
                                    text: "Icon + label"
                                    interactive: true
                                    onClicked: root.lastAction = "Labelled button clicked"
                                }

                                Button {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Active"
                                    interactive: true
                                    active: true
                                }

                                Button {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Static"
                                }

                                RowActions {
                                    anchors.verticalCenter: parent.verticalCenter
                                    hovered: true
                                    showDisconnect: true
                                    showRemove: true
                                    onDisconnectRequested: root.lastAction = "Disconnect requested"
                                    onRemoveRequested: root.lastAction = "Forget requested"
                                }
                            }

                        }

                        GalleryCard {
                            title: "Toggle"

                            Row {
                                spacing: StyleTokens.space16

                                Toggle {
                                    checked: root.toggleValue
                                    onToggled: root.toggleValue = !root.toggleValue
                                }

                                Toggle {
                                    checked: false
                                    onToggled: checked = !checked
                                }

                                Toggle {
                                    checked: true
                                    interactive: false
                                }
                            }
                        }

                        GalleryCard {
                            title: "Slider"

                            Slider {
                                width: parent.width
                                value: root.sliderValue
                                onMoved: (value) => root.sliderValue = value
                            }
                        }

                        GalleryCard {
                            title: "Segmented control"

                            SegmentedControl {
                                width: parent.width
                                labels: ["Output", "Input", "Apps"]
                                currentIndex: root.segmentIndex
                                onSegmentSelected: (index) => root.segmentIndex = index
                            }
                        }

                        GalleryCard {
                            title: "Signal bars"

                            Row {
                                spacing: StyleTokens.space20

                                Repeater {
                                    model: 5

                                    SignalBars {
                                        required property int index
                                        filled: index
                                    }
                                }
                            }
                        }

                        GalleryCard {
                            title: "Icon"

                            Row {
                                spacing: StyleTokens.space16

                                ThemedIcon {
                                    source: IconRegistry.source("system-search-symbolic")
                                }

                                ThemedIcon {
                                    source: IconRegistry.volumeIcon(0.8, false, true)
                                }

                                ThemedIcon {
                                    source: IconRegistry.source("bluetooth-active-symbolic")
                                }
                            }
                        }

                        GalleryCard {
                            title: "Bar group"

                            BarGroup {
                                Row {
                                    Button {
                                        iconName: "system-search-symbolic"
                                        interactive: true
                                    }

                                    Button {
                                        iconName: "utilities-terminal-symbolic"
                                        interactive: true
                                    }

                                    Button {
                                        iconSource: IconRegistry.volumeIcon(0.8, false, true)
                                        interactive: true
                                    }
                                }
                            }
                        }


                        GalleryCard {
                            page: 1
                            title: "Bluetooth"

                            Widgets.BluetoothPopover {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                                springReveal: false
                            }
                        }

                        GalleryCard {
                            page: 1
                            title: "Wi-Fi"

                            Widgets.NetworkPopover {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                                springReveal: false
                            }
                        }

                        GalleryCard {
                            page: 1
                            title: "Sound"

                            Widgets.VolumePopover {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                                springReveal: false
                            }
                        }

                        GalleryCard {
                            page: 1
                            title: "Calendar"

                            Widgets.ClockPopover {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                                springReveal: false
                            }
                        }

                        GalleryCard {
                            page: 1
                            title: "Weather"

                            Widgets.WeatherPopover {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                                springReveal: false
                            }
                        }
                    }
                }
            }
        }
    }
}
