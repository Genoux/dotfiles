import QtQuick
import Quickshell.Widgets
import qs
import qs.config

// A level as one glass slab: a quiet track, a lighter fill whose leading edge
// carries a thin handle, the label at the start and the value at the end. Text
// never inverts -- the fill is translucent, so one colour reads over both
// halves. Drag or click to set the level, wheel to step it, right-click for the
// level's own toggle (mute).
Item {
    id: bar

    property real value: 0
    property real step: StyleControl.sliderStep
    property bool muted: false
    property string label: ""
    property string valueText: bar.muted ? "Muted" : Math.round(bar.shownValue * 100) + "%"

    // The pointer owns the position while it is down: binding straight to a value
    // that round-trips through the audio server makes the edge stutter under the
    // cursor.
    property real shownValue: 0

    readonly property bool scrubbing: dragArea.pressed

    // Opts out of SlidingHighlight, which treats anything reporting `hovered` as
    // a peer.
    readonly property bool hovered: false

    readonly property real fillWidth: width * shownValue
    readonly property real handleX: fillWidth - StyleControl.levelBarHandleInset - StyleControl.levelBarHandleWidth
    // The handle steps aside rather than cutting through the label or the value.
    readonly property bool handleClear: !muted
        && handleX > labelText.x + labelText.contentWidth + StyleControl.levelBarHandleClearance
        && handleX + StyleControl.levelBarHandleWidth < valueLabel.x - StyleControl.levelBarHandleClearance

    signal moved(real value)
    signal muteRequested()

    implicitHeight: StyleControl.levelBarHeight
    height: implicitHeight

    function clamped(v) {
        return Math.max(0, Math.min(1, v))
    }

    function levelAt(x) {
        return x / width
    }

    function commit(v) {
        const next = clamped(v)
        shownValue = next
        bar.moved(next)
    }

    onValueChanged: {
        if (!dragArea.pressed)
            shownValue = clamped(value)
    }

    Component.onCompleted: shownValue = clamped(value)

    // The fill is a whole slab sliding in from the left, clipped by the track,
    // not a rectangle growing from zero: narrower than its own corners, a
    // growing rectangle collapses into a hard sliver standing on the edge.
    ClippingRectangle {
        anchors.fill: parent
        radius: StyleControl.levelBarRadius
        color: StyleControl.levelBarTrack

        Rectangle {
            x: bar.fillWidth - width
            width: parent.width
            height: parent.height
            radius: StyleControl.levelBarRadius
            color: StyleControl.levelBarFill
            // Fades in across its first corner's width, so the last few percent
            // thin out to nothing instead of ending as a bright edge.
            opacity: (bar.muted ? StyleTokens.opacityDisabled : 1)
                * Math.min(1, bar.fillWidth / (StyleControl.levelBarRadius * 2))

            Behavior on opacity {
                NumberAnimation {
                    duration: StyleTokens.motionFeedbackDuration
                    easing.type: StyleTokens.easeFade
                }
            }

            Behavior on x {
                enabled: !dragArea.pressed
                NumberAnimation {
                    duration: StyleTokens.motionFeedbackDuration
                    easing.type: StyleTokens.easeStandard
                }
            }
        }
    }

    Rectangle {
        x: bar.handleX
        anchors.verticalCenter: parent.verticalCenter
        width: StyleControl.levelBarHandleWidth
        height: StyleControl.levelBarHandleHeight
        radius: width / 2
        color: Colors.base07
        opacity: bar.handleClear ? 1 : 0
        transform: Scale {
            origin.y: StyleControl.levelBarHandleHeight / 2
            yScale: bar.scrubbing ? StyleControl.levelBarScrubScale : 1

            Behavior on yScale {
                NumberAnimation {
                    duration: StyleTokens.motionFeedbackDuration
                    easing.type: StyleTokens.easeStandard
                }
            }
        }

        Behavior on x {
            enabled: !dragArea.pressed
            NumberAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeStandard
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: StyleTokens.motionFeedbackDuration
                easing.type: StyleTokens.easeFade
            }
        }
    }

    Text {
        id: labelText

        x: StyleControl.levelBarPadding
        width: Math.max(0, valueLabel.x - StyleControl.levelBarHandleClearance - x)
        anchors.verticalCenter: parent.verticalCenter
        text: bar.label
        elide: Text.ElideRight
        color: Colors.base07
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeMd
    }

    Text {
        id: valueLabel

        x: bar.width - width - StyleControl.levelBarPadding
        anchors.verticalCenter: parent.verticalCenter
        text: bar.valueText
        color: Colors.base07
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeMd
        font.features: ({ "tnum": 1 })
    }

    MouseArea {
        id: dragArea

        anchors.fill: parent
        enabled: bar.enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton)
                bar.muteRequested()
            else
                bar.commit(bar.levelAt(mouse.x))
        }
        onPositionChanged: (mouse) => {
            if (pressedButtons & Qt.LeftButton)
                bar.commit(bar.levelAt(mouse.x))
        }
    }

    WheelHandler {
        enabled: bar.enabled
        onWheel: (event) => bar.commit(bar.shownValue + (event.angleDelta.y > 0 ? bar.step : -bar.step))
    }
}
