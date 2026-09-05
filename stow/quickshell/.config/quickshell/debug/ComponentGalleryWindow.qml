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
    readonly property int surfaceWidth: Math.min(1000, Math.max(640, root.screen.width - galleryMargin * 2))
    readonly property int availableHeight: Math.max(480, root.screen.height - galleryMargin * 2)
    readonly property int surfaceHeight: Math.min(740, availableHeight)

    property bool displayed: false
    property bool toggleValue: true
    property real sliderValue: 0.62
    property int segmentIndex: 1
    property int galleryPage: 1
    property int demoWorkspace: 2
    readonly property int headerHeight: StyleTokens.space20 * 3 + StyleControl.buttonHeight + StyleTokens.space12
    property var iconNames: []
    property string iconFilter: ""

    readonly property var filteredIconNames: iconFilter.length === 0
        ? iconNames
        : iconNames.filter((name) => name.includes(iconFilter))

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

    component GalleryCard: Item {
        id: card

        required property string title
        property int page: 1
        property string description: ""
        readonly property bool inlinePreview: page === 1
        default property alias content: cardContent.data

        visible: root.galleryPage === page
        implicitHeight: (inlinePreview
            ? Math.max(cardHeading.implicitHeight, cardContent.implicitHeight)
            : cardHeading.implicitHeight + StyleTokens.space16 + cardContent.implicitHeight) + StyleTokens.space16 * 2

        onImplicitHeightChanged: {
            if (parent && parent.scheduleLayout)
                parent.scheduleLayout()
        }
        onVisibleChanged: {
            if (parent && parent.scheduleLayout)
                parent.scheduleLayout()
        }

        PopoverSeparator {
            width: parent.width
        }

        Column {
            id: cardHeading
            x: StyleTokens.space16
            y: StyleTokens.space16
            width: card.inlinePreview ? StyleTokens.space20 * 8 : card.width - StyleTokens.space16 * 2
            spacing: StyleTokens.space4

            Text {
                width: parent.width
                text: card.title
                color: Colors.base05
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
                font.weight: Font.DemiBold
            }

            GuideText {
                visible: text.length > 0
                text: card.description
            }
        }

        Column {
            id: cardContent
            x: card.inlinePreview ? cardHeading.x + cardHeading.width + StyleTokens.space20 : StyleTokens.space16
            y: card.inlinePreview ? StyleTokens.space16 : cardHeading.y + cardHeading.implicitHeight + StyleTokens.space16
            width: card.width - x - StyleTokens.space16
            spacing: StyleTokens.space12
        }
    }

    component GuideText: Text {
        width: parent.width
        color: Colors.base04
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeSm
        wrapMode: Text.WordWrap
    }

    component DemoSample: Column {
        property string caption
        default property alias content: sampleContent.data

        width: Math.max(sampleContent.implicitWidth, sampleCaption.implicitWidth)
        spacing: StyleTokens.space8

        Row {
            id: sampleContent
            anchors.horizontalCenter: parent.horizontalCenter
            height: StyleControl.buttonHeight
        }

        Text {
            id: sampleCaption
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.caption
            color: Colors.base04
            font.family: StyleTokens.fontSans
            font.pixelSize: StyleTokens.fontSizeXs
        }
    }

    // GridLayout makes every card in a row as tall as its tallest neighbour,
    // leaving large blank bands under short previews. Place each card in the
    // currently shortest column instead so the gallery stays dense while card
    // heights remain fully content-driven.
    component GalleryMasonry: Item {
        id: masonry

        property int spacing: root.galleryPage === 1 ? 0 : StyleTokens.space12
        readonly property int columnCount: root.galleryPage !== 1 && width >= 840 ? 2 : 1
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
                    height: root.headerHeight

                    Column {
                        anchors.left: parent.left
                        anchors.right: closeButton.left
                        anchors.top: parent.top
                        anchors.margins: StyleTokens.space20
                        spacing: StyleTokens.space4

                        Text {
                            text: "Quickshell style guide"
                            color: Colors.base05
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeLg
                            font.weight: Font.DemiBold
                        }

                    }

                    PillButton {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: StyleTokens.space16
                        iconName: "window-close-symbolic"
                        paddingHorizontal: StylePopover.iconButtonPadding
                        paddingVertical: StylePopover.iconButtonPadding
                        onClicked: Services.ComponentGallery.close()
                    }

                    SegmentedControl {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: StyleTokens.space16
                        labels: ["Theme", "Components", "Widgets", "Icons"]
                        currentIndex: root.galleryPage
                        onSegmentSelected: (index) => root.galleryPage = index
                    }
                }

                PopoverSeparator {
                    width: parent.width
                }

                Flickable {
                    id: galleryFlick

                    visible: root.galleryPage < 3
                    width: parent.width
                    height: parent.height - root.headerHeight - StyleTokens.borderWidth
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
                            page: 0
                            title: "Matugen palette"
                            description: "Current wallpaper colors"

                            Repeater {
                                model: [
                                    { label: "Surfaces · base00–03", colors: [Colors.base00, Colors.base01, Colors.base02, Colors.base03] },
                                    { label: "Content · base04–07", colors: [Colors.base04, Colors.base05, Colors.base06, Colors.base07] },
                                    { label: "Accents · base08–0F", colors: [Colors.base08, Colors.base09, Colors.base0A, Colors.base0B, Colors.base0C, Colors.base0D, Colors.base0E, Colors.base0F] }
                                ]

                                Column {
                                    required property var modelData
                                    width: parent.width
                                    spacing: StyleTokens.space8

                                    GuideText { text: modelData.label }

                                    Row {
                                        id: swatches
                                        readonly property int count: modelData.colors.length
                                        width: parent.width
                                        spacing: StyleTokens.space4

                                        Repeater {
                                            model: modelData.colors

                                            Rectangle {
                                                required property color modelData
                                                width: (swatches.width - (swatches.count - 1) * swatches.spacing) / swatches.count
                                                height: StyleTokens.space20
                                                radius: StyleTokens.radiusXs
                                                color: modelData
                                                border.width: StyleTokens.borderWidth
                                                border.color: StyleOverlay.borderSubtle
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        GalleryCard {
                            page: 0
                            title: "Typography"
                            description: StyleTokens.fontSans

                            Repeater {
                                model: [
                                    { label: "Display", size: StyleTokens.fontSizeXl },
                                    { label: "Title", size: StyleTokens.fontSizeLg },
                                    { label: "Supporting title", size: StyleTokens.fontSizeMd },
                                    { label: "Body and controls", size: StyleTokens.fontSizeSm },
                                    { label: "Metadata", size: StyleTokens.fontSizeXs }
                                ]

                                Text {
                                    required property var modelData
                                    width: parent.width
                                    text: modelData.label + " · " + modelData.size + " px"
                                    color: Colors.base05
                                    font.family: StyleTokens.fontSans
                                    font.pixelSize: modelData.size
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        GalleryCard {
                            page: 0
                            title: "Spacing and shape"

                            Flow {
                                width: parent.width
                                spacing: StyleTokens.space16

                                Repeater {
                                    model: [StyleTokens.space4, StyleTokens.space8, StyleTokens.space12, StyleTokens.space16, StyleTokens.space20]

                                    DemoSample {
                                        required property int modelData
                                        caption: modelData + " px"
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: modelData
                                            height: modelData
                                            color: Colors.base04
                                            radius: StyleTokens.radiusXs
                                        }
                                    }
                                }
                            }

                            GuideText {
                                text: "Radii: " + StyleTokens.radiusXs + " / " + StyleTokens.radiusSm + " / " + StyleTokens.radiusMd
                                    + " px · Borders: " + StyleTokens.borderWidth + " px"
                            }
                        }

                        GalleryCard {
                            title: "Buttons"

                            Flow {
                                width: parent.width
                                spacing: StyleTokens.space20

                                DemoSample {
                                    caption: "Icon only"
                                    Button {
                                        iconName: "system-search-symbolic"
                                        interactive: true
                                    }
                                }

                                DemoSample {
                                    caption: "Icon + label"
                                    Button {
                                        iconName: "utilities-terminal-symbolic"
                                        text: "Terminal"
                                        interactive: true
                                    }
                                }

                                DemoSample {
                                    caption: "Active"
                                    Button {
                                        text: "Selected"
                                        interactive: true
                                        active: true
                                    }
                                }

                                DemoSample {
                                    caption: "Disabled"
                                    Button {
                                        text: "Unavailable"
                                        opacity: StyleTokens.opacityDisabled
                                    }
                                }
                            }
                        }

                        GalleryCard {
                            title: "Row action"

                            RowActions {
                                hovered: true
                                showRemove: true
                                onRemoveRequested: confirming = false
                            }
                        }

                        GalleryCard {
                            title: "Toggles"

                            Flow {
                                width: parent.width
                                spacing: StyleTokens.space20

                                DemoSample {
                                    caption: root.toggleValue ? "On" : "Off"
                                    Toggle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: root.toggleValue
                                        onToggled: {
                                            root.toggleValue = !root.toggleValue
                                        }
                                    }
                                }

                                DemoSample {
                                    caption: "Disabled"
                                    Toggle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: true
                                        interactive: false
                                    }
                                }
                            }
                        }

                        GalleryCard {
                            title: "Slider"

                            Slider {
                                width: parent.width
                                value: root.sliderValue
                                onMoved: (value) => {
                                    root.sliderValue = value
                                }
                            }

                            GuideText { text: "Level · " + Math.round(root.sliderValue * 100) + "%" }
                        }

                        GalleryCard {
                            title: "Segmented control"

                            SegmentedControl {
                                width: parent.width
                                labels: ["Output", "Input", "Apps"]
                                currentIndex: root.segmentIndex
                                onSegmentSelected: (index) => {
                                    root.segmentIndex = index
                                }
                            }
                        }

                        GalleryCard {
                            title: "Bar group"

                            BarGroup {
                                Row {
                                    Repeater {
                                        model: [1, 2, 3]

                                        Button {
                                            required property int modelData
                                            text: modelData
                                            interactive: true
                                            active: root.demoWorkspace === modelData
                                            onClicked: {
                                                root.demoWorkspace = modelData
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        GalleryCard {
                            page: 2
                            title: "Capture"

                            Widgets.CapturePopover {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                            }
                        }

                        GalleryCard {
                            page: 2
                            title: "Bluetooth"

                            Widgets.BluetoothPopover {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                            }
                        }

                        GalleryCard {
                            page: 2
                            title: "Wi-Fi"

                            Widgets.NetworkPopover {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                            }
                        }

                        GalleryCard {
                            page: 2
                            title: "Sound"

                            Widgets.VolumePopover {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                            }
                        }

                        GalleryCard {
                            page: 2
                            title: "Calendar"

                            Widgets.ClockPopover {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                            }
                        }

                        GalleryCard {
                            page: 2
                            title: "Icon menu"

                            PopoverMenu {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                                iconRow: true
                                entries: Services.PowerMenu.entries
                            }
                        }

                        GalleryCard {
                            page: 2
                            title: "Weather"

                            Widgets.WeatherPopover {
                                anchors.horizontalCenter: parent.horizontalCenter
                                active: true
                            }
                        }


                    }
                }

                Column {
                    visible: root.galleryPage === 3
                    width: parent.width
                    height: parent.height - root.headerHeight - StyleTokens.borderWidth

                    Item {
                        width: parent.width
                        height: 52

                        EyebrowLabel {
                            anchors.left: parent.left
                            anchors.leftMargin: StyleTokens.space20
                            anchors.verticalCenter: parent.verticalCenter
                            text: "MacTahoe · " + root.filteredIconNames.length + " symbolic icons"
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
                                source: IconRegistry.barControlIcon("launcher")
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
                                source: IconRegistry.themeIcon(iconCell.modelData)
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

    // The gallery follows the installed pack instead of carrying a generated
    // catalog that drifts whenever MacTahoe adds or renames icons.
    Process {
        command: ["find", "/usr/share/icons/MacTahoe", "-path", "*/symbolic/*.svg", "-printf", "%f\n"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const seen = ({})
                const names = []
                for (const fileName of text.split("\n")) {
                    const name = fileName.replace(/\.svg$/, "")
                    if (name.length === 0 || seen[name])
                        continue
                    seen[name] = true
                    names.push(name)
                }
                root.iconNames = names.sort()
            }
        }
    }
}
