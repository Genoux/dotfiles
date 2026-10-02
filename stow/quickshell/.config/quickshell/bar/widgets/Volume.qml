import QtQuick
import qs.components
import qs.config
import qs.services as Services

Button {
    id: root

    required property var barWindow

    // The active MacTahoe theme supplies a small-size symbolic speaker whose
    // optical weight stays readable beside the other system indicators.
    iconSource: IconRegistry.volumeIcon(Services.AudioState.sinkVolume, Services.AudioState.sinkMuted, Services.AudioState.hasSink)
    interactive: true
    active: popover.open
    onClicked: popover.toggle()

    // Adjusting the level is the one thing worth doing without opening anything.
    WheelHandler {
        onWheel: (event) => Services.AudioState.stepSinkVolume(Math.sign(event.angleDelta.y))
    }

    BarPopover {
        id: popover

        barWindow: root.barWindow
        anchorItem: root

        VolumePopover {
            active: popover.open
        }
    }
}
