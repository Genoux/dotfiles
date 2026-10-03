import QtQuick
import qs
import qs.config

// A panel's primary action: a glyph over a one-line label, sized by the caller
// so a row of them divides its panel's width instead of huddling in the middle
// of it.
Rectangle {
    id: tile

    required property string label
    required property var iconSource
    // A tile that holds a value rather than firing an action becomes the
    // selected chip while that value is on.
    property bool active: false

    signal activated()

    implicitHeight: StylePopover.tileHeight
    height: implicitHeight
    radius: StyleTokens.radiusMd
    // No fill at rest: hover is the travelling SlidingHighlight behind the
    // tile. Active outlasts the pointer, so it is state and one indicator
    // cannot express both.
    color: active ? StyleControl.chipFill : StyleTokens.transparent

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
            tint: tile.active ? StyleControl.chipContent : Colors.base05
        }

        Text {
            width: tile.width
            text: tile.label
            color: tile.active ? StyleControl.chipContent : Colors.base05
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
