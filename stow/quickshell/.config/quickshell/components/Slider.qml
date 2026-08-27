import QtQuick
import qs
import qs.config

// Horizontal level control: click to set, drag to scrub, wheel to step.
//
// Button, PillButton and PopoverAction are all discrete, so none of them owns a
// continuous value. VolumeStepBar stays its separate self on purpose: that one
// reports a level in the OSD, this one sets it.
Item {
    id: slider

    property real value: 0
    property real step: StyleControl.sliderStep

    // The pointer owns the position while it is down. Binding the handle straight
    // to `value` would have it fight the round trip out to the audio server and
    // back, which shows up as a handle that stutters under the cursor. So the
    // shown position is local, and only re-syncs from `value` when nobody is
    // dragging — which also stops the handle snapping backwards on release.
    property real shownValue: 0

    readonly property bool scrubbing: hit.pressed

    signal moved(real value)

    implicitHeight: StyleControl.sliderHitHeight
    height: implicitHeight

    // The handle's centre travels between the two ends rather than its left edge,
    // so clicking the far left reads exactly 0 and the far right exactly 1.
    readonly property real travel: Math.max(1, width - StyleControl.sliderHandleSize)

    function clamped(v) {
        return Math.max(0, Math.min(1, v))
    }

    function valueAt(x) {
        return clamped((x - StyleControl.sliderHandleSize / 2) / slider.travel)
    }

    function commit(v) {
        const next = clamped(v)
        shownValue = next
        slider.moved(next)
    }

    onValueChanged: {
        if (!hit.pressed)
            shownValue = clamped(value)
    }

    Component.onCompleted: shownValue = clamped(value)

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: StyleControl.sliderTrackHeight
        radius: StyleTokens.radiusXs
        color: StyleTokens.alphaLight

        Rectangle {
            // Ends at the handle's centre so fill and handle agree on where the
            // current level is.
            width: StyleControl.sliderHandleSize / 2 + slider.travel * slider.shownValue
            height: parent.height
            radius: parent.radius
            color: Colors.base05
        }
    }

    Rectangle {
        width: StyleControl.sliderHandleSize
        height: width
        radius: width / 2
        x: slider.travel * slider.shownValue
        anchors.verticalCenter: parent.verticalCenter
        color: Colors.base05
        // The handle is the one thing that grows under the pointer, so the grab
        // is legible without moving anything else.
        scale: slider.scrubbing ? 1.15 : 1

        Behavior on scale {
            NumberAnimation {
                duration: StyleTokens.easeDurationFast
                easing.type: StyleTokens.easeStandard
            }
        }
    }

    MouseArea {
        id: hit

        anchors.fill: parent
        // A slider inside a Flickable list must keep the drag it started, or a
        // horizontal scrub gets stolen as a vertical flick.
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => slider.commit(slider.valueAt(mouse.x))
        onPositionChanged: (mouse) => {
            if (pressed)
                slider.commit(slider.valueAt(mouse.x))
        }
    }

    WheelHandler {
        onWheel: (event) => {
            slider.commit(slider.shownValue + (event.angleDelta.y > 0 ? slider.step : -slider.step))
        }
    }
}
