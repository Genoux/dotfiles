import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.config

Rectangle {
    id: root

    default property alias trailContent: trailSlot.data
    property string iconName: ""
    property var iconSource: ""
    property string iconGlyph: ""
    property string iconFont: StyleTokens.fontIcon
    property int iconSize: StyleControl.iconSize
    property string text: ""
    property string fontFamily: StyleTokens.fontSans
    property int fontSize: StyleTokens.fontSizeSm
    property int paddingHorizontal: StyleControl.buttonPaddingHorizontal
    property int paddingRight: paddingHorizontal
    property int paddingVertical: StyleControl.buttonPaddingVertical
    property int iconTextSpacing: StyleControl.iconTextSpacing
    property int minimumWidth: 18
    property int minimumHeight: 20
    property color foreground: Colors.base05
    property color background: StyleTokens.transparent
    property color hoverBackground: StyleTokens.alphaLight
    property int borderWidth: 1
    property color borderColor: StyleTokens.transparent
    property bool interactive: false
    property bool animateColor: true
    property bool manageHoverColor: true
    property bool clipContent: false
    property bool iconColored: false
    property real trailReveal: 0
    property int trailGap: 0
    property int trailWidth: 0
    property int trailPaddingRight: 0
    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool hasText: text.length > 0
    readonly property bool hasImageSource: iconSource !== "" && iconSource !== null
    readonly property var resolvedSource: hasImageSource ? iconSource : IconRegistry.source(iconName)
    readonly property bool usesBundledIcon: hasImageSource ? IconRegistry.isBarIcon(iconSource) : IconRegistry.hasOverride(iconName)
    readonly property bool hasImageIcon: hasImageSource || iconName.length > 0
    readonly property bool showGlyph: iconGlyph.length > 0 && !hasImageIcon
    readonly property bool trailEnabled: trailWidth > 0
    readonly property bool iconOnly: !hasText && trailReveal <= 0 && !trailEnabled
    readonly property int effectiveTrailWidth: trailWidth > 0 ? trailWidth + trailPaddingRight : trailSlot.childrenRect.width
    readonly property int iconDrawSize: Math.round(iconSize * StyleControl.iconVisualScale)
    readonly property int effectiveButtonWidth: iconSize + paddingHorizontal * 2
    readonly property int effectiveButtonHeight: iconSize + paddingVertical * 2
    readonly property int labelLineHeight: iconSize

    signal clicked(var mouse)

    implicitWidth: iconOnly ? Math.max(minimumWidth, effectiveButtonWidth + Math.max(0, paddingRight - paddingHorizontal)) : Math.max(minimumWidth, contentRow.implicitWidth + paddingHorizontal + paddingRight)
    implicitHeight: Math.max(minimumHeight, effectiveButtonHeight)
    width: implicitWidth
    height: implicitHeight
    radius: StyleTokens.radiusSm
    color: root.manageHoverColor && mouseArea.containsMouse && interactive ? hoverBackground : background
    border.width: borderWidth
    border.color: borderColor
    clip: clipContent

    RowLayout {
        id: contentRow

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.trailEnabled ? parent.left : undefined
        anchors.leftMargin: root.trailEnabled ? root.paddingHorizontal : 0
        anchors.horizontalCenter: root.trailEnabled ? undefined : parent.horizontalCenter
        spacing: iconTextSpacing
        Layout.fillHeight: true

        Item {
            id: iconSlot

            visible: root.showGlyph || (root.usesBundledIcon && root.resolvedSource.toString().length > 0) || (!root.usesBundledIcon && root.hasImageIcon && root.resolvedSource.toString().length > 0)
            Layout.preferredWidth: root.iconSize
            Layout.preferredHeight: root.iconSize
            Layout.alignment: Qt.AlignVCenter

            Item {
                id: iconDrawBox

                anchors.centerIn: parent
                width: root.iconDrawSize
                height: root.iconDrawSize

                Text {
                    visible: root.showGlyph
                    anchors.centerIn: parent
                    text: root.iconGlyph
                    color: root.foreground
                    font.family: root.iconFont
                    font.pixelSize: root.iconDrawSize
                }

                Image {
                    id: bundledIcon

                    anchors.fill: parent
                    visible: root.usesBundledIcon && root.resolvedSource.toString().length > 0
                    source: root.resolvedSource
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(root.iconDrawSize, root.iconDrawSize)
                }

                ColorOverlay {
                    anchors.fill: parent
                    visible: bundledIcon.visible && !root.iconColored
                    source: bundledIcon
                    color: root.foreground
                }

                IconImage {
                    id: symbolicIcon

                    anchors.fill: parent
                    visible: !root.usesBundledIcon && root.hasImageIcon && root.resolvedSource.toString().length > 0
                    source: root.resolvedSource
                }

            }

        }

        Text {
            id: labelText

            visible: root.hasText
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: root.labelLineHeight
            Layout.alignment: Qt.AlignVCenter
            text: root.text
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            id: trailSlot

            visible: root.trailReveal > 0
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: root.trailGap * root.trailReveal
            Layout.preferredWidth: root.effectiveTrailWidth * root.trailReveal
            Layout.preferredHeight: Math.max(root.labelLineHeight, childrenRect.height)
            clip: true
        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        acceptedButtons: root.interactive ? Qt.LeftButton | Qt.RightButton | Qt.MiddleButton : Qt.NoButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true
        onClicked: (mouse) => {
            return root.clicked(mouse);
        }
    }

    Behavior on color {
        enabled: root.animateColor

        ColorAnimation {
            duration: StyleTokens.easeDurationFast
            easing.type: Easing.InOutQuad
        }

    }

}
