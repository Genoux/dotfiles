import QtQuick
import qs
import qs.config

// A level as one rounded bar: a quiet track and a bright fill that grows from the
// glyph. The value rides the fill's end: inside it, dark on the bright fill,
// while there is room for it, and just past it, light on the track, once the
// fill is too short to hold it -- so it is always next to the level it names and
// never on top of the glyph. Click or drag anywhere to set the level, wheel to
// step it, click the glyph for its own action (mute).
Item {
    id: bar

    property real value: 0
    property real step: StyleControl.sliderStep
    property var iconSource: ""
    property bool muted: false
    property bool iconInteractive: true
    property bool showValue: true

    // The pointer owns the position while it is down: binding straight to a value
    // that round-trips through the audio server makes the edge stutter under the
    // cursor.
    property real shownValue: 0

    readonly property bool scrubbing: dragArea.pressed

    // Opts out of SlidingHighlight, which treats anything reporting `hovered` as
    // a peer.
    readonly property bool hovered: false

    readonly property int barWidth: width
    readonly property real fillWidth: barHeight + (barWidth - barHeight) * shownValue
    readonly property string valueText: Math.round(shownValue * 100) + "%"
    readonly property real valueWidth: valueMeasure.width
    // Room for the value between the glyph and the fill's end.
    readonly property bool valueFits: fillWidth >= barHeight + valueWidth + StyleControl.levelBarValuePadding
    readonly property int barHeight: StyleControl.levelBarHeight

    signal moved(real value)
    signal iconClicked()

    implicitHeight: barHeight
    height: implicitHeight

    function clamped(v) {
        return Math.max(0, Math.min(1, v))
    }

    function commit(v) {
        const next = clamped(v)
        shownValue = next
        bar.moved(next)
    }

    function levelAt(x) {
        return (x - barHeight / 2) / (barWidth - barHeight)
    }

    onValueChanged: {
        if (!dragArea.pressed)
            shownValue = clamped(value)
    }

    Component.onCompleted: shownValue = clamped(value)

    Rectangle {
        id: track

        y: (bar.height - height) / 2
        width: bar.barWidth
        height: bar.barHeight
        radius: height / 2
        color: StyleTokens.alphaLight
        clip: true

        Rectangle {
            id: fill

            height: parent.height
            // Never narrower than the bar is tall, so the glyph always has its
            // fill behind it.
            width: bar.fillWidth
            radius: height / 2
            color: Colors.base05
            opacity: bar.muted ? StyleTokens.opacityDisabled : (bar.scrubbing ? 1 : 0.92)

            Behavior on opacity {
                NumberAnimation {
                    duration: StyleTokens.motionFeedbackDuration
                    easing.type: StyleTokens.easeFade
                }
            }

            Behavior on width {
                enabled: !dragArea.pressed
                NumberAnimation {
                    duration: StyleTokens.motionFeedbackDuration
                    easing.type: StyleTokens.easeStandard
                }
            }
        }
    }

    TextMetrics {
        id: valueMeasure

        text: "100%"
        font: valueInside.font
    }

    Text {
        id: valueInside

        x: bar.fillWidth - width - StyleControl.levelBarValuePadding
        anchors.verticalCenter: parent.verticalCenter
        visible: bar.showValue
        text: bar.valueText
        color: Colors.base00
        opacity: bar.valueFits && !bar.muted ? 1 : 0
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeSm
        font.weight: Font.DemiBold

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeFade
            }
        }
    }

    Text {
        x: bar.fillWidth + StyleControl.levelBarValuePadding
        anchors.verticalCenter: parent.verticalCenter
        visible: bar.showValue
        text: bar.valueText
        color: Colors.base05
        opacity: bar.valueFits && !bar.muted ? 0 : 1
        font: valueInside.font

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeFade
            }
        }
    }

    ThemedIcon {
        anchors.left: parent.left
        anchors.leftMargin: (bar.barHeight - height) / 2
        anchors.verticalCenter: parent.verticalCenter
        size: StyleControl.levelBarIconSize
        source: bar.iconSource
        tint: Colors.base00
        opacity: bar.muted ? StyleTokens.opacityDisabled : 1
    }

    MouseArea {
        id: dragArea

        width: bar.barWidth
        height: parent.height
        enabled: bar.enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => bar.commit(bar.levelAt(mouse.x))
        onPositionChanged: (mouse) => {
            if (pressed)
                bar.commit(bar.levelAt(mouse.x))
        }
    }

    MouseArea {
        width: bar.barHeight
        height: parent.height
        enabled: bar.enabled && bar.iconInteractive
        cursorShape: Qt.PointingHandCursor
        onClicked: bar.iconClicked()
    }

    WheelHandler {
        onWheel: (event) => bar.commit(bar.shownValue + (event.angleDelta.y > 0 ? bar.step : -bar.step))
    }
}
