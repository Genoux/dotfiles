import QtQuick
import QtQuick.Controls as Controls
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

    readonly property bool scrubbing: control.pressed

    signal moved(real value)

    implicitHeight: StyleControl.sliderHitHeight
    height: implicitHeight

    // The handle's centre travels between the two ends rather than its left edge,
    // so clicking the far left reads exactly 0 and the far right exactly 1.
    function clamped(v) {
        return Math.max(0, Math.min(1, v))
    }

    function commit(v) {
        const next = clamped(v)
        shownValue = next
        slider.moved(next)
    }

    onValueChanged: {
        if (!control.pressed)
            shownValue = clamped(value)
    }

    onShownValueChanged: {
        if (!control.pressed && control.value !== shownValue)
            control.value = shownValue
    }

    Component.onCompleted: shownValue = clamped(value)

    Controls.Slider {
        id: control

        anchors.fill: parent
        from: 0
        to: 1
        live: true
        // Keep this imperative. Binding the control's writable value back to
        // shownValue lets the handle move, but forces `value` back to the old
        // server level before onMoved can publish the user's new position.
        Component.onCompleted: value = slider.shownValue
        onMoved: slider.commit(value)

        background: Rectangle {
            x: control.leftPadding
            y: control.topPadding + control.availableHeight / 2 - height / 2
            width: control.availableWidth
            height: StyleControl.sliderTrackHeight
            radius: StyleTokens.radiusXs
            color: StyleTokens.alphaLight

            Rectangle {
                width: parent.width * control.visualPosition
                height: parent.height
                radius: parent.radius
                color: Colors.base05
            }
        }

        handle: Rectangle {
            x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
            y: control.topPadding + control.availableHeight / 2 - height / 2
            width: StyleControl.sliderHandleSize
            height: width
            radius: width / 2
            color: Colors.base05
            scale: slider.scrubbing ? 1.15 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: StyleTokens.easeDurationFast
                    easing.type: StyleTokens.easeStandard
                }
            }
        }
    }

    WheelHandler {
        onWheel: (event) => {
            slider.commit(slider.shownValue + (event.angleDelta.y > 0 ? slider.step : -slider.step))
        }
    }
}
