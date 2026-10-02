import QtQuick
import qs
import qs.config

// A panel's primary action: a glyph over a one-line label, sized by the caller
// so a row of them divides its panel's width instead of huddling in the middle
// of it (PopoverAction's stacked tile is a fixed 72px built for a row of four).
Rectangle {
    id: tile

    required property string label
    required property var iconSource
    // A tile that holds a value rather than firing an action keeps a fill
    // while that value is on, the way an open popover's bar button does.
    property bool active: false

    signal activated()

    implicitHeight: StylePopover.tileHeight
    height: implicitHeight
    radius: StyleTokens.radiusSm
    // Active keeps its own fill: it outlasts the pointer, so it is state
    // rather than hover and one travelling indicator cannot express both.
    color: active ? StyleTokens.alphaActive : StyleTokens.transparent

    readonly property bool hovered: tileArea.containsMouse

    Behavior on color {
        ColorAnimation {
            duration: StyleTokens.motionFeedbackDuration
            easing.type: StyleTokens.easeFade
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: StyleTokens.space4

        ThemedIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            source: tile.iconSource
            size: StylePopover.tileIconSize
            tint: tile.active ? Colors.base05 : Colors.base04
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
