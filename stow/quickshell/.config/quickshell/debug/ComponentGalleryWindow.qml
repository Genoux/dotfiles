import Quickshell
import Quickshell.Io
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
    property int galleryPage: 0
    property var iconNames: []
    property string iconFilter: ""

    readonly property var filteredIconNames: iconFilter.length === 0
        ? iconNames
        : iconNames.filter((name) => name.includes(iconFilter))
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
    // Not "quickshell": that layer rule animates the surface itself, so a
    // fullscreen window gets the compositor's fade on top of the panel's own
    // reveal. Overlay surfaces own their motion, like the launcher.
    WlrLayershell.namespace: "component-gallery"

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

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: Services.ComponentGallery.close()
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
                        width: 300
                        anchors.right: parent.right
                        anchors.rightMargin: StyleTokens.space16 + StyleControl.buttonWidth + StyleTokens.space8
                        anchors.verticalCenter: parent.verticalCenter
                        labels: ["Components", "Widgets", "Icons"]
                        currentIndex: root.galleryPage
                        onSegmentSelected: (index) => root.galleryPage = index
                    }
                }

                PopoverSeparator {
                    width: parent.width
                }

                Flickable {
                    id: galleryFlick

                    visible: root.galleryPage < 2
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
                            title: "Capture"

                            Widgets.CapturePopover {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                                springReveal: false
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
                            title: "Icon menu"

                            PopoverMenu {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                                springReveal: false
                                iconRow: true
                                entries: Services.PowerMenu.entries
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

                Column {
                    visible: root.galleryPage === 2
                    width: parent.width
                    height: parent.height - 69

                    Item {
                        width: parent.width
                        height: 52

                        EyebrowLabel {
                            anchors.left: parent.left
                            anchors.leftMargin: StyleTokens.space20
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Material Symbols Rounded · " + root.filteredIconNames.length + " icons"
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: StyleTokens.space20
                            anchors.verticalCenter: parent.verticalCenter
                            width: 240
                            height: StyleControl.buttonHeight
                            radius: height / 2
                            color: StyleTokens.alphaLight

                            ThemedIcon {
                                id: searchGlyph

                                anchors.left: parent.left
                                anchors.leftMargin: StyleTokens.space10
                                anchors.verticalCenter: parent.verticalCenter
                                source: IconRegistry.materialIcon("search")
                                tint: Colors.base04
                            }

                            TextInput {
                                anchors.left: searchGlyph.right
                                anchors.leftMargin: StyleTokens.space8
                                anchors.right: parent.right
                                anchors.rightMargin: StyleTokens.space10
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.iconFilter
                                color: Colors.base05
                                selectionColor: StyleOverlay.borderSubtle
                                selectedTextColor: Colors.base05
                                font.family: StyleTokens.fontSans
                                font.pixelSize: StyleTokens.fontSizeSm
                                clip: true
                                cursorVisible: activeFocus
                                onTextChanged: root.iconFilter = text

                                Text {
                                    anchors.fill: parent
                                    visible: parent.text.length === 0
                                    text: "Filter icons"
                                    color: Colors.base04
                                    font: parent.font
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                    GridView {
                        width: parent.width
                        height: parent.height - 52
                        leftMargin: StyleTokens.space16
                        rightMargin: StyleTokens.space16
                        topMargin: StyleTokens.space16
                        bottomMargin: StyleTokens.space16
                        cellWidth: 116
                        cellHeight: 92
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.filteredIconNames

                        delegate: Column {
                            id: iconCell

                            required property string modelData

                            width: 116
                            spacing: StyleTokens.space4

                            ThemedIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: IconRegistry.materialIcon(iconCell.modelData)
                                size: StyleControl.iconSize * 1.5
                            }

                            Text {
                                width: parent.width
                                text: iconCell.modelData
                                color: Colors.base04
                                font.family: StyleTokens.fontMono
                                font.pixelSize: StyleTokens.fontSizeXs
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    // Material Symbols is a ligature font: QML cannot enumerate its glyphs, so
    // the name list is generated from the installed TTF. Regenerate after a
    // ttf-material-symbols-variable update.
    FileView {
        path: Quickshell.shellPath("assets/material-symbols.txt")
        printErrors: false
        onLoaded: root.iconNames = text().split("\n").filter((name) => name.length > 0)
    }
}
